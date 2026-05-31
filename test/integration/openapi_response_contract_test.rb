require "test_helper"
require "yaml"

class OpenapiResponseContractTest < ActionDispatch::IntegrationTest
  test "service invoice responses expose documented contract keys" do
    bootstrap = bootstrap_organization(slug: unique_slug("contract"))
    token = bootstrap.dig("owner", "api_token")
    profile = create_fiscal_profile(token: token)
    customer = create_customer(token: token)

    create_service_invoice(token: token, fiscal_profile_id: profile.fetch("id"), customer_id: customer.fetch("id"))
    assert_openapi_response!("post", "/v1/service_invoices", "201", json_response)

    service_invoice = json_response.fetch("service_invoice")
    assert_required_keys(service_invoice, %w[
      id
      status
      service_description
      service_code
      amount_cents
      tax_rate_bps
      lock_version
      fiscal_profile
      customer
      created_by
    ])
  end

  test "registry list responses satisfy documented OpenAPI required fields" do
    bootstrap = bootstrap_organization(slug: unique_slug("registry-contract"))
    token = bootstrap.dig("owner", "api_token")
    create_fiscal_profile(token: token)
    create_customer(token: token)

    get "/v1/memberships", headers: auth_headers(token)
    assert_response :success
    assert_openapi_response!("get", "/v1/memberships", "200", json_response)

    get "/v1/fiscal_profiles", headers: auth_headers(token)
    assert_response :success
    assert_openapi_response!("get", "/v1/fiscal_profiles", "200", json_response)

    get "/v1/customers", headers: auth_headers(token)
    assert_response :success
    assert_openapi_response!("get", "/v1/customers", "200", json_response)
  end

  test "service invoice list response satisfies documented OpenAPI required fields" do
    bootstrap = bootstrap_organization(slug: unique_slug("invoice-list-contract"))
    token = bootstrap.dig("owner", "api_token")
    profile = create_fiscal_profile(token: token)
    customer = create_customer(token: token)
    create_service_invoice(token: token, fiscal_profile_id: profile.fetch("id"), customer_id: customer.fetch("id"))

    get "/v1/service_invoices", headers: auth_headers(token)

    assert_response :success
    assert_openapi_response!("get", "/v1/service_invoices", "200", json_response)
  end

  test "OpenAPI keeps versioned paths and shared error responses" do
    openapi = YAML.safe_load(File.read(Rails.root.join("openapi.yaml")), aliases: true)

    assert_equal "3.1.0", openapi.fetch("openapi")
    assert_includes openapi.fetch("paths").keys, "/v1/service_invoices"
    assert_includes openapi.fetch("paths").keys, "/v1/service_invoices/{id}/issue"
    assert_equal "bearer", openapi.dig("components", "securitySchemes", "BearerAuth", "scheme")
    assert openapi.dig("components", "responses").key?("ValidationFailed")
  end

  private

  def openapi
    @openapi ||= YAML.safe_load(File.read(Rails.root.join("openapi.yaml")), aliases: true)
  end

  def assert_openapi_response!(method, path, status, payload)
    schema = openapi.dig("paths", path, method, "responses", status, "content", "application/json", "schema")

    assert schema.present?, "OpenAPI must define a JSON schema for #{method.upcase} #{path} #{status}"
    assert_schema!(payload, schema, path)
  end

  def assert_schema!(payload, schema, path)
    schema = normalize_schema(schema)
    required_fields = schema.fetch("required", [])

    required_fields.each do |field|
      assert payload.key?(field), "#{path} must include #{field.inspect}"
      assert_not_nil payload.fetch(field), "#{path}.#{field} must not be nil"
    end

    schema.fetch("properties", {}).each do |field, property_schema|
      next unless payload.key?(field)
      next if payload[field].nil?

      assert_schema_type!(payload[field], property_schema, "#{path}.#{field}")
    end
  end

  def assert_schema_type!(value, schema, path)
    schema = normalize_schema(schema)

    case schema["type"]
    when "object"
      assert_kind_of Hash, value, "#{path} must be an object"
      assert_schema!(value, schema, path)
    when "array"
      assert_kind_of Array, value, "#{path} must be an array"
      value.each_with_index { |item, index| assert_schema_type!(item, schema.fetch("items"), "#{path}[#{index}]") }
    when "integer"
      assert_kind_of Integer, value, "#{path} must be an integer"
    when "boolean"
      assert_includes [ true, false ], value, "#{path} must be a boolean"
    when "string"
      assert_kind_of String, value, "#{path} must be a string"
    end
  end

  def normalize_schema(schema)
    return normalize_schema(resolve_ref(schema.fetch("$ref"))) if schema.key?("$ref")
    return schema unless schema.key?("allOf")

    schema.fetch("allOf").each_with_object({ "type" => "object", "required" => [], "properties" => {} }) do |subschema, merged|
      normalized = normalize_schema(subschema)
      merged["required"] |= normalized.fetch("required", [])
      merged["properties"].merge!(normalized.fetch("properties", {}))
    end
  end

  def resolve_ref(ref)
    ref.delete_prefix("#/").split("/").reduce(openapi) { |document, key| document.fetch(key) }
  end

  def assert_required_keys(payload, keys)
    keys.each { |key| assert payload.key?(key), "expected #{key} in #{payload.inspect}" }
  end
end
