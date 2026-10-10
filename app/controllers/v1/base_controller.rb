class V1::BaseController < ApplicationController
  rate_limit to: 120, within: 1.minute, with: -> { render_error "Too many requests. Try again in a minute.", :too_many_requests }

  before_action :authenticate

  rescue_from ActiveRecord::RecordNotFound, with: -> { render_error "Not found.", :not_found }
  rescue_from ActiveRecord::RecordInvalid, with: ->(error) { render_error error.record.errors.full_messages.to_sentence, :unprocessable_entity }
  rescue_from ActionController::ParameterMissing, with: ->(error) { render_error "Missing parameter: #{error.param}.", :bad_request }
  rescue_from DotenvFormat::ParseError, with: ->(error) { render_error "Could not read the file: #{error.message}.", :unprocessable_entity }
  rescue_from MasterKey::Missing, with: ->(error) { render_error "The vault is not configured: #{error.message}", :service_unavailable }
  rescue_from SecretCipher::DecryptionError, with: ->(error) { audit("decrypt", outcome: "error"); render_error "The vault #{error.message}.", :internal_server_error }

  private
    attr_reader :current_key

    # Authorization: Bearer av_xxxxxxxx_...
    def authenticate
      token = request.authorization.to_s[/\ABearer\s+(\S+)\z/i, 1]
      @current_key = ApiKey.authenticate(token)
      return current_key.update_columns(last_used_at: Time.current) if current_key

      AuditEntry.record("authenticate", key_prefix: ApiKey.prefix_of(token), outcome: "denied", ip: request.remote_ip)
      response.headers["WWW-Authenticate"] = 'Bearer realm="arcline-vault"'
      render_error "A valid API key is required.", :unauthorized
    end

    def require_admin
      deny("This needs a key with write access to all environments.") unless current_key.admin?
    end

    def environment
      @environment ||= Environment.find_by!(name: params[:env_name])
    end

    # A key that may not see an environment is told it does not exist, so it
    # cannot learn which environments there are.
    def require_read
      raise ActiveRecord::RecordNotFound unless current_key.can_read?(environment)
    end

    def require_write
      require_read
      deny("This API key is read-only.") unless current_key.can_write?(environment)
    end

    def deny(message)
      audit(action_name, outcome: "denied")
      render_error message, :forbidden
    end

    def audit(action, secret: "", outcome: "ok")
      AuditEntry.record(action, key_prefix: current_key&.prefix, environment: params[:env_name], secret: secret, outcome: outcome, ip: request.remote_ip)
    end

    def render_error(message, status)
      render json: { error: message }, status: status
    end
end
