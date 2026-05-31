module Invoices
  class Cancel
    def self.call!(invoice:, actor:, expected_lock_version:, reason:)
      ActiveRecord::Base.transaction do
        invoice.lock!
        raise InvalidTransition, "Service invoice version is stale." unless invoice.lock_version == expected_lock_version
        raise InvalidTransition, "Only issued invoices can be cancelled." unless invoice.can_cancel?

        invoice.update!(
          status: "pending_cancellation",
          cancellation_reason: reason
        )

        ProviderRequest.create!(
          organization: invoice.organization,
          service_invoice: invoice,
          provider_name: "sandbox_nfse",
          action: "cancel",
          status: "pending",
          request_payload: { reason: reason, service_invoice: invoice.as_api_json },
          correlation_id: Current.correlation_id || SecureRandom.uuid,
          idempotency_key: "cancel:#{invoice.organization_id}:#{invoice.id}:#{invoice.lock_version}"
        )

        Auditing::Logger.log!(
          organization: invoice.organization,
          membership: actor,
          auditable: invoice,
          action: "service_invoice.cancel_requested",
          metadata: { invoice_id: invoice.public_id, reason: reason }
        )

        Events::Publisher.publish!(
          organization: invoice.organization,
          aggregate: invoice,
          event_type: "service_invoice.cancel_requested",
          payload: { service_invoice: invoice.as_api_json, actor_membership_id: actor.id }
        )

        ActiveRecord.after_all_transactions_commit do
          CancelServiceInvoiceJob.perform_later(invoice.id)
        end
      end

      invoice
    end
  end
end
