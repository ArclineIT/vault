# A bearer token. The token is shown once when the key is created; after that
# only a bcrypt hash and the first eight characters are kept.
class ApiKey < ApplicationRecord
  TOKEN = /\Aav_(?<prefix>[a-z0-9]{8})_(?<secret>[A-Za-z0-9]{40})\z/
  COST = Rails.env.test? ? BCrypt::Engine::MIN_COST : 12
  # Compared against when no key matches, so a miss takes as long as a hit.
  DUMMY_DIGEST = BCrypt::Password.create("no such key", cost: COST).to_s.freeze

  has_many :api_key_grants, dependent: :delete_all
  has_many :environments, through: :api_key_grants

  normalizes :name, with: ->(name) { name.to_s.strip }

  validates :name, presence: true
  validates :prefix, presence: true, uniqueness: true

  scope :active, -> { where(revoked_at: nil) }

  # Returns [ key, token ]. The token cannot be recovered later.
  def self.issue!(name:, read_only: false, environments: nil)
    prefix = SecureRandom.alphanumeric(8).downcase
    token = "av_#{prefix}_#{SecureRandom.alphanumeric(40)}"

    key = transaction do
      create!(name: name, prefix: prefix, read_only: read_only, all_environments: environments.nil?,
              token_digest: BCrypt::Password.create(token, cost: COST)).tap do |created|
        created.environments = Array(environments)
      end
    end
    [ key, token ]
  end

  # The active key a token belongs to, or nil. Takes the same time either way.
  def self.authenticate(token)
    match = TOKEN.match(token.to_s)
    key = match && active.find_by(prefix: match[:prefix])
    valid = BCrypt::Password.new(key&.token_digest || DUMMY_DIGEST).is_password?(token.to_s)
    key if key && valid
  end

  def self.prefix_of(token)
    TOKEN.match(token.to_s)&.[](:prefix).to_s
  end

  def revoked? = revoked_at.present?

  def revoke!
    update!(revoked_at: Time.current)
  end

  def can_read?(environment)
    all_environments? || environment_ids.include?(environment.id)
  end

  def can_write?(environment)
    !read_only? && can_read?(environment)
  end

  # Creating environments and reading the audit log are for unrestricted keys.
  def admin?
    all_environments? && !read_only?
  end

  def visible_environments
    all_environments? ? Environment.ordered : environments.ordered
  end

  def scope_label
    [ all_environments? ? "all environments" : environments.map(&:name).sort.join(", ").presence || "no environments", ("read-only" if read_only?) ].compact.join(", ")
  end
end
