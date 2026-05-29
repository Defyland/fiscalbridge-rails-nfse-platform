if Organization.exists?
  puts "FiscalBridge seed skipped: organizations already exist."
else
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

  puts "Seeded organization #{result.organization.slug}"
  puts "Owner token: #{result.api_token}"
end
