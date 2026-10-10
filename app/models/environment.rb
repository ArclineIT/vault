# A namespace for secrets, such as "production" or "staging".
class Environment < ApplicationRecord
  NAME = /\A[a-z0-9][a-z0-9_-]{0,62}\z/

  has_many :secrets, dependent: :destroy
  has_many :api_key_grants, dependent: :delete_all

  normalizes :name, with: ->(name) { name.to_s.strip.downcase }

  validates :name, presence: true, uniqueness: true, format: { with: NAME, message: "may only use lowercase letters, digits, hyphens and underscores" }

  scope :ordered, -> { order(:name) }

  def to_param = name
end
