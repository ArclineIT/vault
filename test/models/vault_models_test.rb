require "test_helper"

class VaultModelsTest < ActiveSupport::TestCase
  setup { @production = Environment.create!(name: "production") }

  test "a stored secret keeps only ciphertext in the database" do
    Secret.store!(@production, name: "DATABASE_URL", value: "postgres://user:hunter2@db/app", description: "primary", tags: [ "db", " core " ])
    row = ActiveRecord::Base.connection.select_one("SELECT * FROM secrets")

    assert_not row.values.any? { |column| column.to_s.include?("hunter2") }
    secret = Secret.sole
    assert_equal "postgres://user:hunter2@db/app", secret.value
    assert_equal [ "primary", %w[ db core ] ], [ secret.description, secret.tag_list ]
    assert_not secret.summary.key?(:value)
  end

  test "storing again replaces the value and keeps the description unless given" do
    Secret.store!(@production, name: "TOKEN", value: "one", description: "first")
    Secret.store!(@production, name: "TOKEN", value: "two")

    assert_equal 1, Secret.count
    assert_equal [ "two", "first" ], [ Secret.sole.value, Secret.sole.description ]
  end

  test "names are validated and unique per environment, and values are bounded" do
    [ "", "1ABC", "has space", "a/b", "../x", "na\nme" ].each do |name|
      assert_raises(ActiveRecord::RecordInvalid, name.inspect) { Secret.store!(@production, name: name, value: "x") }
    end
    assert_raises(ActiveRecord::RecordInvalid) { Secret.store!(@production, name: "BIG", value: "x" * (Secret::MAX_VALUE_BYTES + 1)) }

    Secret.store!(@production, name: "SAME", value: "prod")
    Secret.store!(Environment.create!(name: "staging"), name: "SAME", value: "stage")
    assert_equal %w[ prod stage ], Secret.order(:id).map(&:value)
  end

  test "environment names are lowercase and URL-safe" do
    assert_equal "staging", Environment.create!(name: " Staging ").name
    [ "", "has space", "a/b", "-lead", "production" ].each { |name| assert_not Environment.new(name: name).valid?, name.inspect }
  end

  test "deleting an environment deletes its secrets" do
    Secret.store!(@production, name: "A", value: "1")
    assert_difference -> { Secret.count }, -1 do
      @production.destroy
    end
  end

  test "an issued token authenticates, and only its hash and prefix are kept" do
    key, token = ApiKey.issue!(name: "ci")

    assert_match ApiKey::TOKEN, token
    assert_equal key, ApiKey.authenticate(token)
    assert_equal token[3, 8], key.prefix
    assert_not_includes key.attributes.values.map(&:to_s).join, token
    assert key.token_digest.start_with?("$2a$")
  end

  test "wrong, malformed and revoked tokens do not authenticate" do
    key, token = ApiKey.issue!(name: "ci")

    assert_nil ApiKey.authenticate(token.chop + (token[-1] == "a" ? "b" : "a"))
    assert_nil ApiKey.authenticate("av_#{key.prefix}_#{'x' * 40}")
    [ nil, "", "Bearer", "av_short_x", token.upcase, " #{token}" ].each { |bad| assert_nil ApiKey.authenticate(bad), bad.inspect }

    key.revoke!
    assert_nil ApiKey.authenticate(token)
  end

  test "a key's reach depends on its grants and its read-only flag" do
    staging = Environment.create!(name: "staging")
    all, = ApiKey.issue!(name: "admin")
    reader, = ApiKey.issue!(name: "reader", read_only: true)
    scoped, = ApiKey.issue!(name: "deploy", environments: [ staging ])
    scoped_reader, = ApiKey.issue!(name: "viewer", environments: [ staging ], read_only: true)

    assert all.admin? && all.can_write?(@production)
    assert reader.can_read?(@production) && !reader.can_write?(@production) && !reader.admin?
    assert scoped.can_write?(staging) && !scoped.can_read?(@production) && !scoped.admin?
    assert scoped_reader.can_read?(staging) && !scoped_reader.can_write?(staging)

    assert_equal %w[ production staging ], all.visible_environments.map(&:name)
    assert_equal %w[ staging ], scoped.visible_environments.map(&:name)
    assert_equal "staging, read-only", scoped_reader.scope_label
    assert_equal "all environments", all.scope_label
  end
end
