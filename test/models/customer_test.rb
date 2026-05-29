require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  test "normalizes Brazilian document and email" do
    organization = Organization.create!(name: "Customer Tenant", slug: unique_slug("customer"))

    customer = organization.customers.create!(
      legal_name: "Buyer Ltda",
      document_type: "cnpj",
      document_number: "22.333.444/0001-55",
      email: "FINANCE@BUYER.TEST",
      city_code: "3550308"
    )

    assert_equal "22333444000155", customer.document_number
    assert_equal "finance@buyer.test", customer.email
  end
end
