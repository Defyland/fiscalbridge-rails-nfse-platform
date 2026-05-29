module V1
  class ServiceInvoicesController < ApplicationController
    def index
      authorize!(:service_invoices_list)

      invoices = current_organization.service_invoices.includes(:fiscal_profile, :customer, :created_by_membership)
                                      .recent_first
      invoices = invoices.where(status: params[:status]) if params[:status].present?
      invoices = invoices.where(customer_id: params[:customer_id]) if params[:customer_id].present?

      render json: { service_invoices: invoices.map(&:as_api_json) }
    end

    def create
      authorize!(:service_invoices_create)

      idempotency_key = require_idempotency_key!
      return if performed?

      result = Invoices::Create.call!(
        organization: current_organization,
        actor: current_membership,
        idempotency_key: idempotency_key,
        attributes: service_invoice_params.to_h.symbolize_keys
      )

      set_lock_etag(result.invoice)
      render json: {
        service_invoice: result.invoice.as_api_json,
        idempotent_replay: result.idempotent_replay
      }, status: result.idempotent_replay ? :ok : :created
    end

    def show
      authorize!(:service_invoices_read)

      invoice = scoped_invoice
      set_lock_etag(invoice)
      render json: { service_invoice: invoice.as_api_json }
    end

    def issue
      authorize!(:service_invoices_issue)

      invoice = scoped_invoice
      expected_lock_version = required_lock_version!("service invoice issuance")
      return if performed?

      Invoices::Issue.call!(
        invoice: invoice,
        actor: current_membership,
        expected_lock_version: expected_lock_version
      )

      invoice.reload
      set_lock_etag(invoice)
      render json: { service_invoice: invoice.as_api_json }, status: :accepted
    end

    def cancel
      authorize!(:service_invoices_cancel)

      invoice = scoped_invoice
      expected_lock_version = required_lock_version!("service invoice cancellation")
      return if performed?

      Invoices::Cancel.call!(
        invoice: invoice,
        actor: current_membership,
        expected_lock_version: expected_lock_version,
        reason: cancel_params.fetch(:reason)
      )

      invoice.reload
      set_lock_etag(invoice)
      render json: { service_invoice: invoice.as_api_json }, status: :accepted
    end

    def poll_status
      authorize!(:service_invoices_poll_status)

      invoice = scoped_invoice
      expected_lock_version = required_lock_version!("service invoice status polling")
      return if performed?

      provider_request = Invoices::PollStatus.call!(
        invoice: invoice,
        actor: current_membership,
        expected_lock_version: expected_lock_version
      )

      render json: { provider_request: provider_request.as_json(except: %i[request_payload response_payload]) },
             status: :accepted
    end

    private

    def scoped_invoice
      current_organization.service_invoices.includes(:fiscal_profile, :customer, :created_by_membership)
                          .find_by!(public_id: params[:id])
    end

    def service_invoice_params
      params.require(:service_invoice).permit(
        :fiscal_profile_id,
        :customer_id,
        :service_description,
        :service_code,
        :amount_cents,
        :tax_rate_bps,
        :iss_withheld
      )
    end

    def cancel_params
      params.require(:cancellation).permit(:reason)
    end
  end
end
