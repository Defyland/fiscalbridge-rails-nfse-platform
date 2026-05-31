module Backoffice
  class ServiceInvoicesController < BaseController
    before_action :set_invoice, only: %i[show issue cancel poll_status]

    def index
      authorize!(:service_invoices_list)

      @status = params[:status].presence
      @service_invoices = current_organization.service_invoices.includes(:customer, :fiscal_profile, :created_by_membership)
                                             .recent_first
      @service_invoices = @service_invoices.where(status: @status) if @status.present?
      @service_invoices = @service_invoices.limit(50)
    end

    def show
      authorize!(:service_invoices_read)

      @provider_requests = @service_invoice.provider_requests.recent_first.limit(20)
      @audit_logs = @service_invoice.audit_logs.order(created_at: :desc).limit(20)
    end

    def issue
      authorize!(:service_invoices_issue)

      Invoices::Issue.call!(
        invoice: @service_invoice,
        actor: current_membership,
        expected_lock_version: expected_lock_version
      )

      redirect_to backoffice_service_invoice_path(@service_invoice.public_id), notice: "Emissao enviada para a fila."
    end

    def cancel
      authorize!(:service_invoices_cancel)

      Invoices::Cancel.call!(
        invoice: @service_invoice,
        actor: current_membership,
        expected_lock_version: expected_lock_version,
        reason: params.require(:cancellation).fetch(:reason)
      )

      redirect_to backoffice_service_invoice_path(@service_invoice.public_id), notice: "Cancelamento enviado para a fila."
    end

    def poll_status
      authorize!(:service_invoices_poll_status)

      Invoices::PollStatus.call!(
        invoice: @service_invoice,
        actor: current_membership,
        expected_lock_version: expected_lock_version
      )

      redirect_to backoffice_service_invoice_path(@service_invoice.public_id), notice: "Consulta de status enviada para a fila."
    end

    private

    def set_invoice
      @service_invoice = current_organization.service_invoices.includes(:customer, :fiscal_profile, :created_by_membership)
                                             .find_by!(public_id: params[:id])
    end

    def expected_lock_version
      Integer(params.require(:lock_version), 10)
    rescue ArgumentError
      raise Invoices::InvalidTransition, "Versao da nota fiscal invalida."
    end
  end
end
