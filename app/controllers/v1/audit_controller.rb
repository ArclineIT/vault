class V1::AuditController < V1::BaseController
  before_action :require_admin

  # GET /v1/audit?limit=100
  def index
    limit = params.fetch(:limit, 100).to_i.clamp(1, 1000)
    render json: { entries: AuditEntry.recent.limit(limit) }
  end
end
