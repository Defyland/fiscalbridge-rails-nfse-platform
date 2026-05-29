require "test_helper"

class FailureScenariosTest < ActionDispatch::IntegrationTest
  test "returns 422 when monthly invoice quota is exhausted" do
    bootstrap = bootstrap_organization(
      slug: unique_slug("invoice-limit"),
      organization_attributes: { monthly_invoice_limit: 1 }
    )
    token = bootstrap.dig("owner", "api_token")
    profile = create_fiscal_profile(token: token)
    customer = create_customer(token: token)

    create_service_invoice(token: token, fiscal_profile_id: profile.fetch("id"), customer_id: customer.fetch("id"))

    post "/v1/service_invoices", params: {
      service_invoice: {
        fiscal_profile_id: profile.fetch("id"),
        customer_id: customer.fetch("id"),
        service_description: "Second invoice",
        service_code: "6201501",
        amount_cents: 100_00
      }
    }, headers: auth_headers(token, "Idempotency-Key" => "second-invoice"), as: :json

    assert_response :unprocessable_entity
    assert_includes json_response.dig("error", "message"), "Monthly invoice limit has been reached"
  end

  test "requires idempotency key for invoice creation" do
    bootstrap = bootstrap_organization(slug: unique_slug("missing-key"))
    token = bootstrap.dig("owner", "api_token")
    profile = create_fiscal_profile(token: token)
    customer = create_customer(token: token)

    post "/v1/service_invoices", params: {
      service_invoice: {
        fiscal_profile_id: profile.fetch("id"),
        customer_id: customer.fetch("id"),
        service_description: "Missing key",
        service_code: "6201501",
        amount_cents: 100_00
      }
    }, headers: auth_headers(token), as: :json

    assert_response :bad_request
    assert_equal "missing_idempotency_key", json_response.dig("error", "code")
  end

  test "provider timeout leaves invoice pending for safe reprocessing" do
    bootstrap = bootstrap_organization(slug: unique_slug("provider-timeout"))
    token = bootstrap.dig("owner", "api_token")
    profile = create_fiscal_profile(token: token)
    customer = create_customer(token: token)
    create_service_invoice(
      token: token,
      fiscal_profile_id: profile.fetch("id"),
      customer_id: customer.fetch("id"),
      attributes: { service_description: "Software implementation [provider_timeout]" }
    )

    get "/v1/service_invoices/NFS-000001", headers: auth_headers(token)
    etag = response.headers.fetch("ETag")

    post "/v1/service_invoices/NFS-000001/issue", headers: auth_headers(token, "If-Match" => etag), as: :json

    assert_response :accepted
    assert_raises(Providers::SandboxNfseClient::TimeoutError) do
      perform_enqueued_jobs(only: IssueServiceInvoiceJob)
    end

    invoice = ServiceInvoice.find_by!(public_id: "NFS-000001")
    assert_equal "pending_issue", invoice.status
    assert_equal "failed", invoice.provider_requests.issue.last.status
    assert AuditLog.exists?(action: "service_invoice.provider_timeout")
  end

  test "duplicate provider callbacks are accepted idempotently" do
    invoice = create_invoice_record(status: "issued")

    2.times do
      post "/v1/provider_callbacks/nfse", params: {
        callback: {
          callback_id: "callback-123",
          provider_invoice_number: invoice.provider_invoice_number,
          status: "issued",
          provider_protocol: "provider-callback-protocol"
        }
      }, headers: { "X-Provider-Token" => "local-provider-token" }, as: :json

      assert_response :accepted
    end

    assert_equal 1, invoice.provider_requests.callback.where(idempotency_key: "callback-123").count
  end
end
