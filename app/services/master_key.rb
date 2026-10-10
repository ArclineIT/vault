# The key that protects every secret's own key. It is read from the environment
# and never written anywhere.
module MasterKey
  Missing = Class.new(StandardError)
  ENV_NAME = "VAULT_MASTER_KEY"

  # 32 bytes, given as 64 hexadecimal characters.
  def self.parse(hex)
    hex = hex.to_s.strip
    raise Missing, "#{ENV_NAME} must be 64 hexadecimal characters (32 bytes). Generate one with: openssl rand -hex 32" unless hex.match?(/\A\h{64}\z/)

    [ hex ].pack("H*")
  end

  def self.current
    parse(ENV[ENV_NAME])
  end

  def self.generate
    SecureRandom.hex(32)
  end
end
