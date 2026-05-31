require "application_system_test_case"

class BackofficeServiceInvoicesTest < ApplicationSystemTestCase
  test "operator inspects invoice lifecycle evidence" do
    invoice = service_invoices(:draft_invoice)

    sign_in_as users(:owner_user)
    click_on "Notas"
    click_on invoice.public_id

    assert_text invoice.public_id
    assert_text invoice.customer.legal_name
    assert_text "Provider requests"
    assert_text "Auditoria"
  end

  test "operator sends draft invoice to issuance queue" do
    invoice = service_invoices(:draft_invoice)

    sign_in_as users(:owner_user)
    visit backoffice_service_invoice_path(invoice.public_id)
    click_on "Emitir"

    assert_text "Emissao enviada para a fila"
    assert_text "pending_issue"
    assert_equal "pending_issue", invoice.reload.status
  end

  test "operator sees conflict when issuing from a stale invoice page" do
    invoice = service_invoices(:draft_invoice)

    sign_in_as users(:owner_user)
    visit backoffice_service_invoice_path(invoice.public_id)
    invoice.update!(service_description: "Updated outside this browser session")
    click_on "Emitir"

    assert_text "Service invoice version is stale"
    assert_equal "draft", invoice.reload.status
  end
end
