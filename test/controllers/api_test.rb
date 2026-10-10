require "test_helper"

class ApiTest < ActionDispatch::IntegrationTest
  setup do
    @production = Environment.create!(name: "production")
    @staging = Environment.create!(name: "staging")
    Secret.store!(@production, name: "DATABASE_URL", value: "postgres://prod", description: "primary db")
    Secret.store!(@production, name: "API_KEY", value: "it's a $ecret\nwith two lines")
    Secret.store!(@staging, name: "DATABASE_URL", value: "postgres://stage")

    _admin, @admin = issue_key
    _reader, @reader = issue_key(read_only: true)
    _deploy, @deploy = issue_key(environments: [ @staging ])
  end

  test "every endpoint needs a valid key" do
    [ [ :get, "/v1/envs" ], [ :get, "/v1/envs/production/secrets" ], [ :get, "/v1/envs/production/secrets/API_KEY" ],
      [ :get, "/v1/envs/production/export" ], [ :get, "/v1/audit" ], [ :post, "/v1/envs" ], [ :delete, "/v1/envs/production/secrets/API_KEY" ] ].each do |verb, path|
      send(verb, path)
      assert_response :unauthorized, "#{verb} #{path}"
      assert_equal "A valid API key is required.", json["error"]

      send(verb, path, headers: bearer("av_abcdefgh_#{'x' * 40}"))
      assert_response :unauthorized
    end
    assert_equal 'Bearer realm="arcline-vault"', response.headers["WWW-Authenticate"]
    assert_equal 2, Secret.where(environment: @production).count
  end

  test "lists environments the key can reach" do
    get "/v1/envs", headers: bearer(@admin)
    assert_equal [ { "name" => "production", "secrets" => 2 }, { "name" => "staging", "secrets" => 1 } ], json["environments"]

    get "/v1/envs", headers: bearer(@deploy)
    assert_equal [ "staging" ], json["environments"].map { |env| env["name"] }
  end

  test "lists secret names without values" do
    get "/v1/envs/production/secrets", headers: bearer(@reader)

    assert_response :success
    assert_equal %w[ API_KEY DATABASE_URL ], json["secrets"].map { |secret| secret["name"] }
    assert_equal "primary db", json["secrets"].last["description"]
    assert_no_match "postgres://prod", response.body
    assert json["secrets"].none? { |secret| secret.key?("value") }
  end

  test "reads one secret" do
    get "/v1/envs/production/secrets/API_KEY", headers: bearer(@reader)

    assert_equal "it's a $ecret\nwith two lines", json["value"]
  end

  test "creates and replaces a secret, including an empty value and a dotted name" do
    post "/v1/envs/production/secrets", params: { name: "NEW_ONE", value: "v1", description: "d", tags: %w[ a b ] }, as: :json, headers: bearer(@admin)
    assert_response :created
    assert_equal({ "name" => "NEW_ONE", "description" => "d", "tags" => %w[ a b ] }, json.slice("name", "description", "tags"))
    assert_not json.key?("value")

    post "/v1/envs/production/secrets", params: { name: "NEW_ONE", value: "" }, as: :json, headers: bearer(@admin)
    assert_response :ok
    assert_equal "", Secret.find_by!(name: "NEW_ONE").value

    post "/v1/envs/production/secrets", params: { name: "app.config-v2", value: "x" }, as: :json, headers: bearer(@admin)
    get "/v1/envs/production/secrets/app.config-v2", headers: bearer(@admin)
    assert_equal "x", json["value"]
  end

  test "rejects a missing value and a bad name" do
    post "/v1/envs/production/secrets", params: { name: "NO_VALUE" }, as: :json, headers: bearer(@admin)
    assert_response :bad_request
    assert_equal "Missing parameter: value.", json["error"]

    post "/v1/envs/production/secrets", params: { name: "bad name", value: "x" }, as: :json, headers: bearer(@admin)
    assert_response :unprocessable_entity
    assert_match "Name must start with a letter or underscore", json["error"]
  end

  test "deletes a secret" do
    delete "/v1/envs/production/secrets/API_KEY", headers: bearer(@admin)
    assert_response :no_content
    assert_not Secret.exists?(environment: @production, name: "API_KEY")

    delete "/v1/envs/production/secrets/API_KEY", headers: bearer(@admin)
    assert_response :not_found
  end

  test "a read-only key cannot change anything" do
    post "/v1/envs/production/secrets", params: { name: "X", value: "x" }, as: :json, headers: bearer(@reader)
    assert_response :forbidden
    assert_equal "This API key is read-only.", json["error"]

    delete "/v1/envs/production/secrets/API_KEY", headers: bearer(@reader)
    assert_response :forbidden
    post "/v1/envs/production/import", params: "X=1", headers: bearer(@reader).merge("Content-Type" => "text/plain")
    assert_response :forbidden
    post "/v1/envs", params: { name: "qa" }, as: :json, headers: bearer(@reader)
    assert_response :forbidden

    assert_equal 3, Secret.count
    assert_equal 2, Environment.count
  end

  test "a scoped key cannot see, read or write other environments, or even learn they exist" do
    [ [ :get, "/v1/envs/production/secrets" ], [ :get, "/v1/envs/production/secrets/API_KEY" ], [ :get, "/v1/envs/production/export" ],
      [ :delete, "/v1/envs/production/secrets/API_KEY" ], [ :get, "/v1/envs/does-not-exist/secrets" ] ].each do |verb, path|
      send(verb, path, headers: bearer(@deploy))
      assert_response :not_found, "#{verb} #{path}"
      assert_equal "Not found.", json["error"]
    end

    post "/v1/envs/production/secrets", params: { name: "X", value: "x" }, as: :json, headers: bearer(@deploy)
    assert_response :not_found

    get "/v1/envs/staging/secrets/DATABASE_URL", headers: bearer(@deploy)
    assert_equal "postgres://stage", json["value"]
  end

  test "exports as a .env file and as JSON" do
    get "/v1/envs/production/export", headers: bearer(@reader)
    assert_equal "text/plain; charset=utf-8", response.headers["Content-Type"]
    assert_equal({ "API_KEY" => "it's a $ecret\nwith two lines", "DATABASE_URL" => "postgres://prod" }, DotenvFormat.parse(response.body))

    get "/v1/envs/production/export?format=json", headers: bearer(@reader)
    assert_equal({ "API_KEY" => "it's a $ecret\nwith two lines", "DATABASE_URL" => "postgres://prod" }, json)
  end

  test "imports a .env file, all or nothing" do
    post "/v1/envs/staging/import", params: "# comment\nNEW=1\nDATABASE_URL='postgres://replaced'\n", headers: bearer(@deploy).merge("Content-Type" => "text/plain")
    assert_response :success
    assert_equal %w[ NEW DATABASE_URL ], json["imported"]
    assert_equal "postgres://replaced", Secret.find_by!(environment: @staging, name: "DATABASE_URL").value

    post "/v1/envs/staging/import", params: "GOOD=1\nthis is not valid\n", headers: bearer(@deploy).merge("Content-Type" => "text/plain")
    assert_response :unprocessable_entity
    assert_equal "Could not read the file: line 2 is not NAME=value.", json["error"]
    assert_not Secret.exists?(name: "GOOD")
  end

  test "an admin key creates and deletes environments" do
    post "/v1/envs", params: { name: "QA" }, as: :json, headers: bearer(@admin)
    assert_response :created
    assert_equal "qa", json["name"]

    post "/v1/envs", params: { name: "qa" }, as: :json, headers: bearer(@admin)
    assert_response :unprocessable_entity

    post "/v1/envs", params: { name: "x" }, as: :json, headers: bearer(@deploy)
    assert_response :forbidden

    delete "/v1/envs/staging", headers: bearer(@admin)
    assert_response :no_content
    assert_equal 0, Secret.where(environment_id: @staging.id).count
  end

  test "access is logged without values, and only an admin key can read the log" do
    get "/v1/envs/production/secrets/API_KEY", headers: bearer(@reader)
    post "/v1/envs/production/secrets", params: { name: "X", value: "top-secret-value" }, as: :json, headers: bearer(@reader)
    get "/v1/envs", headers: bearer("av_zzzzzzzz_#{'q' * 40}")

    get "/v1/audit", headers: bearer(@reader)
    assert_response :forbidden

    get "/v1/audit", headers: bearer(@admin)
    entries = json["entries"]
    read = entries.find { |entry| entry["action"] == "secret.read" }
    assert_equal [ @reader[3, 8], "production", "API_KEY", "ok" ], read.values_at("key", "environment", "secret", "outcome")
    assert entries.any? { |entry| entry["action"] == "create" && entry["outcome"] == "denied" }
    assert entries.any? { |entry| entry["action"] == "authenticate" && entry["outcome"] == "denied" && entry["key"] == "zzzzzzzz" }
    assert_no_match "top-secret-value", response.body
    assert_no_match @reader, response.body
  end

  test "a wrong master key is an error, not garbage" do
    original = ENV["VAULT_MASTER_KEY"]
    ENV["VAULT_MASTER_KEY"] = "aa" * 32
    get "/v1/envs/production/secrets/API_KEY", headers: bearer(@reader)
    assert_response :internal_server_error
    assert_match "master key is wrong", json["error"]

    ENV["VAULT_MASTER_KEY"] = ""
    get "/v1/envs/production/export", headers: bearer(@reader)
    assert_response :service_unavailable
    assert_match "VAULT_MASTER_KEY must be 64 hexadecimal characters", json["error"]
  ensure
    ENV["VAULT_MASTER_KEY"] = original
  end

  test "the front door and health check need no key and reveal nothing" do
    get "/"
    assert_equal "arcline-vault", json["service"]

    get "/up"
    assert_response :success
  end
end
