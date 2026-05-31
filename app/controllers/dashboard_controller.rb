class DashboardController < Backoffice::BaseController
  def show
    authorize!(:organizations_read)

    @organization = current_organization
    @invoice_counts = @organization.service_invoices.group(:status).count
    @recent_invoices = @organization.service_invoices.includes(:customer, :fiscal_profile)
                                   .recent_first
                                   .limit(8)
    @pending_provider_requests = @organization.provider_requests.pending.count
    @failed_outbound_events = @organization.outbound_events.failed.count
  end
end
