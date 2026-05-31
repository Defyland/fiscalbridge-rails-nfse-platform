module Invoices
  class Issue
    def self.call!(invoice:, actor:, expected_lock_version:)
      ActiveRecord::Base.transaction do
        invoice.lock!
        raise InvalidTransition, "Service invoice version is stale." unless invoice.lock_version == expected_lock_version
        raise InvalidTransition, "Only draft or rejected invoices can be issued." unless invoice.can_issue?

        invoice.update!(
          status: "pending_issue",
          rejection_reason: nil,
          provider_protocol: nil
        )

        ProviderRequest.create!(
          organization: invoice.organization,
          service_invoice: invoice,
          provider_name: "sandbox_nfse",
          action: "issue",
          status: "pending",
          request_payload: invoice.as_api_json,
          correlation_id: Current.correlation_id || SecureRandom.uuid,
          idempotency_key: "issue:#{invoice.organization_id}:#{invoice.id}:#{invoice.lock_version}"
        )

        Auditing::Logger.log!(
          organization: invoice.organization,
          membership: actor,
          auditable: invoice,
          action: "service_invoice.issue_requested",
          metadata: { invoice_id: invoice.public_id }
        )

        Events::Publisher.publish!(
          organization: invoice.organization,
          aggregate: invoice,
          event_type: "service_invoice.issue_requested",
          payload: { service_invoice: invoice.as_api_json, actor_membership_id: actor.id }
        )

        ActiveRecord.after_all_transactions_commit do
          IssueServiceInvoiceJob.perform_later(invoice.id)
        end
      end

      invoice
    end
  end
end
