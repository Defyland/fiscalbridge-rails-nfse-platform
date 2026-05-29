require "test_helper"

class FiscalProfileTest < ActiveSupport::TestCase
  test "requires tenant scoped fiscal identity" do
    organization = Organization.create!(name: "Fiscal Tenant", slug: unique_slug("fiscal"))

    profile = organization.fiscal_profiles.create!(
      legal_name: "Acme Fiscal Ltda",
      tax_id: "11.222.333/0001-81",
      municipal_registration: "123456",
      city_code: "3550308",
      service_list_item: "01.07",
      taxation_regime: "simples_nacional"
    )

    assert_equal "11222333000181", profile.tax_id
    assert profile.valid?
  end
end
