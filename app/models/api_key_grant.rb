class ApiKeyGrant < ApplicationRecord
  belongs_to :api_key
  belongs_to :environment
end
