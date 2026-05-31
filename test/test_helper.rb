ENV["RAILS_ENV"] ||= "test"
require "simplecov"

SimpleCov.start("rails") do
  add_filter "/test/"
end

require_relative "../config/environment"
require "rails/test_help"
require "active_job/test_helper"

Dir[Rails.root.join("test/support/**/*.rb")].sort.each { |file| require file }

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all
    include ActiveJob::TestHelper

    setup do
      Security::RateLimiter.reset!
      Observability::MetricsRegistry.reset!
      clear_enqueued_jobs
      clear_performed_jobs
    end
  end
end

class ActionDispatch::IntegrationTest
  include ApiTestHelper
end

module TestRecordHelper
  def unique_slug(prefix = "tenant")
    "#{prefix}-#{SecureRandom.hex(4)}"
  end

  def create_membership(organization:, email: nil, role: "operator")
    token, digest = Tokens::Issuer.issue
    organization.memberships.create!(
      email: email || "#{role}-#{SecureRandom.hex(4)}@tenant.test",
      full_name: "#{role.to_s.titleize} User",
      role: role,
      state: "active",
      api_token_digest: digest,
      api_token_last_eight: token.last(8),
      api_token_expires_at: Tokens::Issuer.expires_at
    )
  end

  def create_profile(organization:)
    organization.fiscal_profiles.create!(
      legal_name: "Acme Fiscal Ltda",
      tax_id: "11#{SecureRandom.random_number(10**12).to_s.rjust(12, '0')}",
      municipal_registration: "123456",
      city_code: "3550308",
      service_list_item: "01.07",
      taxation_regime: "simples_nacional",
      environment: "sandbox"
    )
  end

  def create_customer_record(organization:, document_number: nil)
    organization.customers.create!(
      legal_name: "Buyer #{SecureRandom.hex(3)} Ltda",
      document_type: "cnpj",
      document_number: document_number || "22#{SecureRandom.random_number(10**12).to_s.rjust(12, '0')}",
      email: "finance-#{SecureRandom.hex(3)}@buyer.test",
      city_code: "3550308"
    )
  end

  def create_invoice_record(organization: nil, status: "draft", idempotency_key: nil)
    organization ||= Organization.create!(name: "Invoice Tenant", slug: unique_slug("invoice"))
    organization.service_invoices.create!(
      fiscal_profile: create_profile(organization: organization),
      customer: create_customer_record(organization: organization),
      created_by_membership: create_membership(organization: organization),
      public_id: "NFS-#{SecureRandom.random_number(999_999).to_s.rjust(6, '0')}",
      idempotency_key: idempotency_key || SecureRandom.uuid,
      status: status,
      service_description: "Implementation services",
      service_code: "6201501",
      amount_cents: 100_00,
      provider_invoice_number: status == "issued" ? "NFSE-#{SecureRandom.hex(5)}" : nil,
      issued_at: status == "issued" ? Time.current : nil
    )
  end
end

module SingletonStubHelper
  def with_stubbed_singleton(target, method_name, replacement)
    singleton_class = class << target; self; end
    original = target.method(method_name)

    singleton_class.define_method(method_name) do |*args, **kwargs, &block|
      replacement.call(*args, **kwargs, &block)
    end

    yield
  ensure
    singleton_class.define_method(method_name) do |*args, **kwargs, &block|
      original.call(*args, **kwargs, &block)
    end
  end
end

module ActiveSupport
  class TestCase
    include TestRecordHelper
    include SingletonStubHelper
  end
end

class ActionDispatch::IntegrationTest
  include TestRecordHelper
  include SingletonStubHelper
end
