ENV["RAILS_ENV"] ||= "test"
# A fixed key for the test run only.
ENV["VAULT_MASTER_KEY"] = "0f" * 32
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/stub_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    include StubHelper
  end
end

module ApiTestHelper
  def issue_key(**options)
    ApiKey.issue!(name: "test", **options)
  end

  def bearer(token)
    { "Authorization" => "Bearer #{token}" }
  end

  def json
    response.parsed_body
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) { include ApiTestHelper }
