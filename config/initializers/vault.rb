# Refuse to start in production without a usable master key, rather than
# failing on the first request.
Rails.application.config.after_initialize do
  MasterKey.current if Rails.env.production? && !ENV["SECRET_KEY_BASE_DUMMY"]
end
