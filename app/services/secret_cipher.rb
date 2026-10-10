require "openssl"

# Envelope encryption with AES-256-GCM. Each value is encrypted with a fresh
# data key, and the data key is encrypted ("wrapped") with the master key.
# Rotating the master key therefore only means re-wrapping the data keys.
#
# Both ciphertexts are bound to where the secret lives ("environment/NAME"), so
# a row copied onto another secret will not decrypt.
class SecretCipher
  DecryptionError = Class.new(StandardError)
  Sealed = Data.define(:ciphertext, :wrapped_key)

  ALGORITHM = "aes-256-gcm"
  NONCE_BYTES = 12
  TAG_BYTES = 16

  def initialize(master_key = MasterKey.current)
    @master_key = master_key
  end

  def encrypt(value, context:)
    data_key = OpenSSL::Random.random_bytes(32)
    Sealed.new(ciphertext: seal(value.to_s.b, data_key, context), wrapped_key: seal(data_key, @master_key, context))
  end

  def decrypt(ciphertext, wrapped_key, context:)
    data_key = open(wrapped_key, @master_key, context)
    open(ciphertext, data_key, context).force_encoding(Encoding::UTF_8)
  end

  # Re-wraps a data key under a new master key without touching the value.
  def rewrap(wrapped_key, new_master_key, context:)
    seal(open(wrapped_key, @master_key, context), new_master_key, context)
  end

  private
    # nonce || tag || ciphertext
    def seal(plaintext, key, context)
      cipher = OpenSSL::Cipher.new(ALGORITHM).encrypt
      cipher.key = key
      nonce = cipher.random_iv
      cipher.auth_data = context
      encrypted = cipher.update(plaintext) + cipher.final
      nonce + cipher.auth_tag(TAG_BYTES) + encrypted
    end

    def open(sealed, key, context)
      sealed = sealed.to_s.b
      raise DecryptionError, "stored value is too short to be valid" if sealed.bytesize < NONCE_BYTES + TAG_BYTES

      cipher = OpenSSL::Cipher.new(ALGORITHM).decrypt
      cipher.key = key
      cipher.iv = sealed.byteslice(0, NONCE_BYTES)
      cipher.auth_tag = sealed.byteslice(NONCE_BYTES, TAG_BYTES)
      cipher.auth_data = context
      cipher.update(sealed.byteslice(NONCE_BYTES + TAG_BYTES..)) + cipher.final
    rescue OpenSSL::Cipher::CipherError
      raise DecryptionError, "could not decrypt: the master key is wrong or the stored value was altered"
    end
end
