require "test_helper"

class ServiceInvoicesFlowTest < ActionDispatch::IntegrationTest
  test "creates an idempotent invoice and issues it asynchronously" do
    bootstrap = bootstrap_organization(slug: unique_slug("invoice-flow"))
    token = bootstrap.dig("owner", "api_token")
    profile = create_fiscal_profile(token: token)
    customer = create_customer(token: token)

    invoice = create_service_invoice(
      token: token,
      fiscal_profile_id: profile.fetch("id"),
      customer_id: customer.fetch("id"),
      idempotency_key: "invoice-flow-key"
    )

    assert_equal "NFS-000001", invoice.fetch("id")
    assert_equal "draft", invoice.fetch("status")

    post "/v1/service_invoices", params: {
      service_invoice: {
        fiscal_profile_id: profile.fetch("id"),
        customer_id: customer.fetch("id"),
        service_description: "Software implementation services",
        service_code: "6201501",
        amount_cents: 150_00
      }
    }, headers: auth_headers(token, "Idempotency-Key" => "invoice-flow-key"), as: :json

    assert_response :success
    assert_equal true, json_response.fetch("idempotent_replay")
    assert_equal "NFS-000001", json_response.dig("service_invoice", "id")

    get "/v1/service_invoices/NFS-000001", headers: auth_headers(token)
    assert_response :success
    etag = response.headers.fetch("ETag")

    perform_enqueued_jobs do
      post "/v1/service_invoices/NFS-000001/issue", headers: auth_headers(token, "If-Match" => etag), as: :json
      assert_response :accepted
    end

    get "/v1/service_invoices/NFS-000001", headers: auth_headers(token)

    assert_response :success
    assert_equal "issued", json_response.dig("service_invoice", "status")
    assert_match(/\ANFSE-NFS-000001\z/, json_response.dig("service_invoice", "provider_invoice_number"))
  end

  test "cancels an issued invoice asynchronously" do
    bootstrap = bootstrap_organization(slug: unique_slug("cancel-flow"))
    token = bootstrap.dig("owner", "api_token")
    profile = create_fiscal_profile(token: token)
    customer = create_customer(token: token)
    create_service_invoice(token: token, fiscal_profile_id: profile.fetch("id"), customer_id: customer.fetch("id"))

    get "/v1/service_invoices/NFS-000001", headers: auth_headers(token)
    issue_etag = response.headers.fetch("ETag")

    perform_enqueued_jobs do
      post "/v1/service_invoices/NFS-000001/issue", headers: auth_headers(token, "If-Match" => issue_etag), as: :json
      assert_response :accepted
    end

    get "/v1/service_invoices/NFS-000001", headers: auth_headers(token)
    cancel_etag = response.headers.fetch("ETag")

    perform_enqueued_jobs do
      post "/v1/service_invoices/NFS-000001/cancel", params: {
        cancellation: { reason: "Customer requested cancellation" }
      }, headers: auth_headers(token, "If-Match" => cancel_etag), as: :json
      assert_response :accepted
    end

    get "/v1/service_invoices/NFS-000001", headers: auth_headers(token)

    assert_response :success
    assert_equal "cancelled", json_response.dig("service_invoice", "status")
    assert_not_nil json_response.dig("service_invoice", "cancelled_at")
  end
end
