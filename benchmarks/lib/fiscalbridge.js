import http from "k6/http";
import { check } from "k6";

const BASE_URL = __ENV.BASE_URL || "http://127.0.0.1:3000";

function failWithResponse(label, response) {
  throw new Error(`${label} failed with status ${response.status}: ${response.body}`);
}

function expectStatus(response, status, label) {
  const ok = check(response, { [label]: (res) => res.status === status });
  if (!ok) {
    failWithResponse(label, response);
  }
}

function expectJsonValue(response, path, label) {
  const value = response.json(path);

  if (value === undefined || value === null || value === "") {
    throw new Error(`${label} missing in response body: ${response.body}`);
  }

  return value;
}

function requestCorrelationId(label = "bench") {
  const vu = typeof __VU === "number" ? __VU : "setup";
  const iter = typeof __ITER === "number" ? __ITER : Date.now();
  return `${label}-${vu}-${iter}`;
}

function jsonHeaders(extra = {}) {
  return Object.assign({
    "Content-Type": "application/json",
    "X-Correlation-ID": requestCorrelationId("bench")
  }, extra);
}

function authed(token, extra = {}) {
  return jsonHeaders(Object.assign({ Authorization: `Bearer ${token}` }, extra));
}

export function setupTenant() {
  const suffix = `${Date.now()}-${Math.floor(Math.random() * 100000)}`;
  const bootstrap = http.post(`${BASE_URL}/v1/organizations`, JSON.stringify({
    organization: {
      name: `Bench Fiscal ${suffix}`,
      slug: `bench-fiscal-${suffix}`,
      legal_name: "Bench Fiscal Ltda",
      tax_id: "11222333000181",
      municipal_registration: "123456",
      plan: "growth",
      monthly_invoice_limit: 100000
    },
    owner: {
      email: `owner-${suffix}@bench.test`,
      full_name: "Benchmark Owner"
    }
  }), { headers: jsonHeaders() });

  expectStatus(bootstrap, 201, "bootstrap created");

  const token = expectJsonValue(bootstrap, "owner.api_token", "owner.api_token");

  const profile = http.post(`${BASE_URL}/v1/fiscal_profiles`, JSON.stringify({
    fiscal_profile: {
      legal_name: "Bench Fiscal Ltda",
      tax_id: "11222333000181",
      municipal_registration: "123456",
      city_code: "3550308",
      service_list_item: "01.07",
      taxation_regime: "simples_nacional",
      environment: "sandbox"
    }
  }), { headers: authed(token) });
  expectStatus(profile, 201, "fiscal profile created");

  const customer = http.post(`${BASE_URL}/v1/customers`, JSON.stringify({
    customer: {
      legal_name: "Benchmark Buyer Ltda",
      document_type: "cnpj",
      document_number: "22333444000155",
      email: "finance@bench.test",
      city_code: "3550308"
    }
  }), { headers: authed(token) });
  expectStatus(customer, 201, "customer created");

  return {
    token,
    profileId: expectJsonValue(profile, "fiscal_profile.id", "fiscal_profile.id"),
    customerId: expectJsonValue(customer, "customer.id", "customer.id")
  };
}

export function smokeScenario(data) {
  const read = http.get(`${BASE_URL}/v1/organization`, { headers: authed(data.token) });
  expectStatus(read, 200, "organization read");

  mixedApiScenario(data);
}

export function mixedApiScenario(data) {
  const key = `bench-invoice-${__VU}-${__ITER}-${Date.now()}`;
  const created = http.post(`${BASE_URL}/v1/service_invoices`, JSON.stringify({
    service_invoice: {
      fiscal_profile_id: data.profileId,
      customer_id: data.customerId,
      service_description: "Benchmark implementation service",
      service_code: "6201501",
      amount_cents: 10000,
      tax_rate_bps: 200
    }
  }), { headers: authed(data.token, { "Idempotency-Key": key }) });

  expectStatus(created, 201, "invoice created");
  const invoiceId = expectJsonValue(created, "service_invoice.id", "service_invoice.id");

  const read = http.get(`${BASE_URL}/v1/service_invoices/${invoiceId}`, { headers: authed(data.token) });
  expectStatus(read, 200, "invoice read");
}
