class V1::EnvironmentsController < V1::BaseController
  before_action :require_admin, only: %i[ create destroy ]

  # GET /v1/envs
  def index
    render json: { environments: current_key.visible_environments.map { |env| { name: env.name, secrets: env.secrets.count } } }
  end

  # POST /v1/envs  { "name": "staging" }
  def create
    created = Environment.create!(name: params.require(:name))
    AuditEntry.record("env.create", key_prefix: current_key.prefix, environment: created.name, ip: request.remote_ip)
    render json: { name: created.name }, status: :created
  end

  # DELETE /v1/envs/:env  — removes the environment and every secret in it.
  def destroy
    environment.destroy!
    audit("env.delete")
    head :no_content
  end
end
