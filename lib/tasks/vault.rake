namespace :vault do
  desc "Print a new master key"
  task :generate_key do
    require "securerandom"
    puts SecureRandom.hex(32)
  end

  desc "Check that every secret decrypts with the current master key"
  task verify: :environment do
    cipher = SecretCipher.new
    broken = Secret.includes(:environment).reject do |secret|
      secret.value(cipher: cipher)
      true
    rescue SecretCipher::DecryptionError
      false
    end

    broken.each { |secret| puts "cannot decrypt #{secret.context}" }
    abort "#{broken.size} of #{Secret.count} secrets cannot be decrypted." if broken.any?
    puts "All #{Secret.count} secrets decrypt."
  end

  desc "Re-wrap every secret's key under VAULT_NEW_MASTER_KEY. Afterwards, start the server with the new key."
  task rotate_master_key: :environment do
    new_key = MasterKey.parse(ENV["VAULT_NEW_MASTER_KEY"])
    cipher = SecretCipher.new

    Secret.transaction do
      Secret.includes(:environment).find_each do |secret|
        secret.update_columns(wrapped_key: cipher.rewrap(secret.wrapped_key, new_key, context: secret.context))
      end
    end
    AuditEntry.record("master_key.rotate")
    puts "Re-wrapped #{Secret.count} secrets. Set VAULT_MASTER_KEY to the new key and restart."
  rescue MasterKey::Missing => e
    abort e.message.sub(MasterKey::ENV_NAME, "VAULT_NEW_MASTER_KEY")
  end

  namespace :keys do
    desc "Create an API key: NAME=ci [ENVS=production,staging] [READ_ONLY=1]. Without ENVS the key reaches every environment."
    task create: :environment do
      name = ENV["NAME"].presence or abort "usage: bin/rails vault:keys:create NAME=ci [ENVS=production,staging] [READ_ONLY=1]"
      environments = ENV["ENVS"].presence&.split(",")&.map { |env| Environment.find_or_create_by!(name: env.strip) }

      key, token = ApiKey.issue!(name: name, read_only: ENV["READ_ONLY"].present?, environments: environments)
      AuditEntry.record("key.create", key_prefix: key.prefix)
      puts "Created API key #{key.name.inspect} (#{key.scope_label})."
      puts "Token, shown only this once:"
      puts
      puts "  #{token}"
      puts
    end

    desc "List API keys"
    task list: :environment do
      ApiKey.order(:created_at).each do |key|
        used = key.last_used_at ? "last used #{key.last_used_at.utc.strftime('%Y-%m-%d %H:%M')}" : "never used"
        puts format("%-10s %-20s %-40s %s%s", key.prefix, key.name, key.scope_label, used, key.revoked? ? "  REVOKED" : "")
      end
    end

    desc "Revoke an API key by its prefix: PREFIX=ab12cd34"
    task revoke: :environment do
      key = ApiKey.find_by(prefix: ENV["PREFIX"].to_s) or abort "no key with prefix #{ENV['PREFIX'].inspect}"
      key.revoke!
      AuditEntry.record("key.revoke", key_prefix: key.prefix)
      puts "Revoked #{key.name.inspect} (#{key.prefix})."
    end
  end

  desc "Show the most recent audit entries: [LIMIT=50]"
  task audit: :environment do
    AuditEntry.recent.limit(ENV.fetch("LIMIT", 50).to_i).reverse_each do |entry|
      puts format("%s  %-8s  %-16s %-8s %s", entry.created_at.utc.strftime("%Y-%m-%d %H:%M:%S"), entry.key_prefix.presence || "-", entry.action, entry.outcome,
                  [ entry.environment_name, entry.secret_name ].compact_blank.join("/"))
    end
  end
end
