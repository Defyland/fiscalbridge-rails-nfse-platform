module Invoices
  class PollStatus
    def self.call!(invoice:, actor:, expected_lock_version:)
      provider_request = nil

      ActiveRecord::Base.transaction do
        invoice.lock!
        raise InvalidTransition, "Service invoice version is stale." unless invoice.lock_version == expected_lock_version

        provider_request = ProviderRequest.create!(
          organization: invoice.organization,
          service_invoice: invoice,
          provider_name: "sandbox_nfse",
          action: "status_poll",
          status: "pending",
          request_payload: { service_invoice_id: invoice.public_id },
          correlation_id: Current.correlation_id || SecureRandom.uuid,
          idempotency_key: "status_poll:#{invoice.organization_id}:#{invoice.id}:#{SecureRandom.uuid}"
        )

        Auditing::Logger.log!(
          organization: invoice.organization,
          membership: actor,
          auditable: invoice,
          action: "service_invoice.status_poll_requested",
          metadata: { provider_request_id: provider_request.id }
        )

        ActiveRecord.after_all_transactions_commit do
          StatusPollServiceInvoiceJob.perform_later(invoice.id, provider_request.id)
        end
      end

      provider_request
    end
  end
end
