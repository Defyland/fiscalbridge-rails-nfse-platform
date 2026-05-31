organization = Organization.find_by(slug: "acme-fiscal-ops")
owner_membership = organization&.memberships&.owner&.first
owner_token = nil

unless organization && owner_membership
  result = Organizations::Bootstrap.call!(
    organization_attributes: {
      name: "Acme Fiscal Ops",
      slug: "acme-fiscal-ops",
      legal_name: "Acme Fiscal Ops Ltda",
      tax_id: "11222333000181",
      municipal_registration: "123456",
      plan: "growth",
      seat_limit: 10,
      monthly_invoice_limit: 1000
    },
    owner_attributes: {
      email: "owner@acme.test",
      full_name: "Owner Admin"
    }
  )

  organization = result.organization
  owner_membership = result.owner_membership
  owner_token = result.api_token
end

seed_password = ENV.fetch("SEED_USER_PASSWORD", "password123")
User.find_or_create_by!(email_address: owner_membership.email) do |user|
  user.membership = owner_membership
  user.password = seed_password
  user.password_confirmation = seed_password
end

profile = organization.fiscal_profiles.find_or_create_by!(tax_id: "11222333000181") do |fiscal_profile|
  fiscal_profile.legal_name = "Acme Fiscal Ops Ltda"
  fiscal_profile.trade_name = "Acme Ops"
  fiscal_profile.municipal_registration = "123456"
  fiscal_profile.city_code = "3550308"
  fiscal_profile.service_list_item = "01.07"
  fiscal_profile.taxation_regime = "simples_nacional"
  fiscal_profile.environment = "sandbox"
  fiscal_profile.default_profile = true
end

customer = organization.customers.find_or_create_by!(document_number: "22333444000155") do |record|
  record.legal_name = "Cliente Operacional Ltda"
  record.document_type = "cnpj"
  record.email = "financeiro@cliente.test"
  record.city_code = "3550308"
  record.address_line = "Av. Paulista, 1000"
  record.state_code = "SP"
end

unless organization.service_invoices.exists?(idempotency_key: "seed-web-backoffice")
  Invoices::Create.call!(
    organization: organization,
    actor: owner_membership,
    idempotency_key: "seed-web-backoffice",
    attributes: {
      fiscal_profile_id: profile.id,
      customer_id: customer.id,
      service_description: "Servicos de implantacao e suporte",
      service_code: "6201501",
      amount_cents: 250_00,
      tax_rate_bps: 200,
      iss_withheld: false
    }
  )
end

puts "Seeded organization #{organization.slug}"
puts "Backoffice login: #{owner_membership.email} / #{seed_password}"
puts "Owner token: #{owner_token}" if owner_token
