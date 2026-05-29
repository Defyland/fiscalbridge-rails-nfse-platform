module ApiTestHelper
  def json_response
    JSON.parse(response.body)
  end

  def auth_headers(token, extra = {})
    {
      "Authorization" => "Bearer #{token}",
      "X-Correlation-ID" => "test-correlation-id"
    }.merge(extra)
  end

  def bootstrap_organization(slug:, name: "Acme Support", owner_email: nil, organization_attributes: {})
    owner_email ||= "owner-#{slug}@acme.test"

    post "/v1/organizations", params: {
      organization: {
        name: name,
        slug: slug,
        legal_name: "#{name} Ltda",
        tax_id: "11222333000181",
        municipal_registration: "123456",
        plan: "starter"
      }.merge(organization_attributes),
      owner: {
        email: owner_email,
        full_name: "Owner Admin"
      }
    }, as: :json

    assert_response :created
    json_response
  end

  def create_fiscal_profile(token:, attributes: {})
    post "/v1/fiscal_profiles", params: {
      fiscal_profile: {
        legal_name: "Acme Fiscal Ops Ltda",
        trade_name: "Acme Fiscal",
        tax_id: "11222333000181",
        municipal_registration: "123456",
        city_code: "3550308",
        service_list_item: "01.07",
        taxation_regime: "simples_nacional",
        environment: "sandbox",
        default_profile: true
      }.merge(attributes)
    }, headers: auth_headers(token), as: :json

    assert_response :created
    json_response.fetch("fiscal_profile")
  end

  def create_customer(token:, attributes: {})
    post "/v1/customers", params: {
      customer: {
        legal_name: "Beta Buyer Ltda",
        document_type: "cnpj",
        document_number: "22333444000155",
        email: "finance@buyer.test",
        city_code: "3550308",
        address_line: "Rua Fiscal, 100",
        state_code: "SP",
        country_code: "BR"
      }.merge(attributes)
    }, headers: auth_headers(token), as: :json

    assert_response :created
    json_response.fetch("customer")
  end

  def create_service_invoice(token:, fiscal_profile_id:, customer_id:, idempotency_key: SecureRandom.uuid, attributes: {})
    post "/v1/service_invoices", params: {
      service_invoice: {
        fiscal_profile_id: fiscal_profile_id,
        customer_id: customer_id,
        service_description: "Software implementation services",
        service_code: "6201501",
        amount_cents: 150_00,
        tax_rate_bps: 200,
        iss_withheld: false
      }.merge(attributes)
    }, headers: auth_headers(token, "Idempotency-Key" => idempotency_key), as: :json

    assert_response :created
    json_response.fetch("service_invoice")
  end
end
