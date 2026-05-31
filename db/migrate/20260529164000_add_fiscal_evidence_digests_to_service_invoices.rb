class AddFiscalEvidenceDigestsToServiceInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :service_invoices, :xml_sha256, :string
    add_column :service_invoices, :pdf_sha256, :string
    add_column :service_invoices, :evidence_recorded_at, :datetime

    add_check_constraint :service_invoices,
                         "xml_sha256 IS NULL OR xml_sha256 ~ '^[0-9a-f]{64}$'",
                         name: "service_invoices_xml_sha256_valid"
    add_check_constraint :service_invoices,
                         "pdf_sha256 IS NULL OR pdf_sha256 ~ '^[0-9a-f]{64}$'",
                         name: "service_invoices_pdf_sha256_valid"
  end
end
