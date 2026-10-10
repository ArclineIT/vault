class V1::SecretsController < V1::BaseController
  before_action :require_read, only: %i[ index show export ]
  before_action :require_write, only: %i[ create destroy import ]

  # GET /v1/envs/:env/secrets  — names only, never values.
  def index
    audit("secret.list")
    render json: { environment: environment.name, secrets: environment.secrets.ordered.map(&:summary) }
  end

  # GET /v1/envs/:env/secrets/:name
  def show
    secret = environment.secrets.find_by!(name: params[:name])
    value = secret.value
    audit("secret.read", secret: secret.name)
    render json: secret.summary.merge(value: value)
  end

  # POST /v1/envs/:env/secrets  { "name": "...", "value": "...", "description": "...", "tags": [...] }
  def create
    existed = environment.secrets.exists?(name: params.require(:name).to_s.strip)
    # An empty value is allowed; a missing one is not.
    value = params.fetch(:value) { raise ActionController::ParameterMissing, :value }
    secret = Secret.store!(environment, name: params[:name], value: value, description: params[:description], tags: params[:tags])
    audit(existed ? "secret.update" : "secret.create", secret: secret.name)
    render json: secret.summary, status: existed ? :ok : :created
  end

  # DELETE /v1/envs/:env/secrets/:name
  def destroy
    secret = environment.secrets.find_by!(name: params[:name])
    secret.destroy!
    audit("secret.delete", secret: secret.name)
    head :no_content
  end

  # GET /v1/envs/:env/export            — .env text
  # GET /v1/envs/:env/export?format=json
  def export
    pairs = environment.secrets.ordered.to_h { |secret| [ secret.name, secret.value ] }
    audit("secret.export")

    if params[:format] == "json"
      render json: pairs
    else
      render plain: DotenvFormat.dump(pairs)
    end
  end

  # POST /v1/envs/:env/import  — the body is a .env file. All or nothing.
  def import
    pairs = DotenvFormat.parse(request.raw_post.force_encoding(Encoding::UTF_8))
    Secret.transaction { pairs.each { |name, value| Secret.store!(environment, name: name, value: value) } }
    audit("secret.import")
    render json: { imported: pairs.keys }
  end
end
