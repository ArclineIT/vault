# One line of the access log: who (by key prefix) did what to which secret.
# Values are never recorded.
class AuditEntry < ApplicationRecord
  scope :recent, -> { order(created_at: :desc, id: :desc) }

  def self.record(action, key_prefix: "", environment: "", secret: "", outcome: "ok", ip: "")
    create!(action: action, key_prefix: key_prefix.to_s, environment_name: environment.to_s, secret_name: secret.to_s,
            outcome: outcome, ip_address: ip.to_s, created_at: Time.current)
  end

  def as_json(*)
    { at: created_at.utc.iso8601, key: key_prefix, action: action, environment: environment_name, secret: secret_name, outcome: outcome, ip: ip_address }
  end
end
