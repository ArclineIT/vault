# A named value in one environment. Only the encrypted form is stored; the
# plaintext exists in memory for the length of one request.
class Secret < ApplicationRecord
  NAME = /\A[A-Za-z_][A-Za-z0-9_.-]{0,254}\z/
  MAX_VALUE_BYTES = 64.kilobytes

  belongs_to :environment

  normalizes :name, :description, with: ->(value) { value.to_s.strip }

  validates :name, presence: true, uniqueness: { scope: :environment_id },
                   format: { with: NAME, message: "must start with a letter or underscore and use only letters, digits, underscores, dots and hyphens" }
  validates :ciphertext, :wrapped_key, presence: { message: "is missing: set a value" }

  scope :ordered, -> { order(:name) }

  # Creates or replaces a secret's value.
  def self.store!(environment, name:, value:, description: nil, tags: nil, cipher: SecretCipher.new)
    secret = environment.secrets.find_or_initialize_by(name: name.to_s.strip)
    secret.description = description unless description.nil?
    secret.tags = tags unless tags.nil?
    secret.set_value(value, cipher: cipher)
    secret.save!
    secret
  end

  def set_value(value, cipher: SecretCipher.new)
    value = value.to_s
    raise ActiveRecord::RecordInvalid.new(self.tap { errors.add(:value, "is too large (#{MAX_VALUE_BYTES / 1024} KB at most)") }) if value.bytesize > MAX_VALUE_BYTES

    sealed = cipher.encrypt(value, context: context)
    self.ciphertext, self.wrapped_key = sealed.ciphertext, sealed.wrapped_key
  end

  def value(cipher: SecretCipher.new)
    cipher.decrypt(ciphertext, wrapped_key, context: context)
  end

  def tag_list = tags.split(",")

  # Accepts a list or a comma-separated string.
  def tags=(value)
    super(Array(value).flat_map { |tag| tag.to_s.split(",") }.map(&:strip).compact_blank.uniq.join(","))
  end

  # Where this secret lives; mixed into the encryption so rows cannot be swapped.
  def context
    "#{environment.name}/#{name}"
  end

  # Never the value.
  def summary
    { name: name, description: description, tags: tag_list, updated_at: updated_at&.utc&.iso8601 }
  end
end
