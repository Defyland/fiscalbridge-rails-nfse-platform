module Invoices
  class Create
    Result = Struct.new(:invoice, :idempotent_replay, keyword_init: true)

    def self.call!(organization:, actor:, idempotency_key:, attributes:)
      existing = organization.service_invoices.find_by(idempotency_key: idempotency_key)
      return Result.new(invoice: existing, idempotent_replay: true) if existing

      invoice = nil

      ActiveRecord::Base.transaction do
        organization.lock!

        unless organization.invoice_quota_available?
          organization.errors.add(:monthly_invoice_limit, "has been reached for the current month")
          raise ActiveRecord::RecordInvalid, organization
        end

        public_id = format("NFS-%06d", organization.next_invoice_sequence)

        invoice = organization.service_invoices.create!(
          attributes.merge(
            public_id: public_id,
            idempotency_key: idempotency_key,
            created_by_membership: actor
          )
        )

        organization.update!(
          current_month_invoice_count: organization.current_month_invoice_count + 1,
          next_invoice_sequence: organization.next_invoice_sequence + 1
        )

        Auditing::Logger.log!(
          organization: organization,
          membership: actor,
          auditable: invoice,
          action: "service_invoice.created",
          metadata: { invoice_id: invoice.public_id, amount_cents: invoice.amount_cents }
        )

        Events::Publisher.publish!(
          organization: organization,
          aggregate: invoice,
          event_type: "service_invoice.created",
          payload: {
            service_invoice: invoice.as_api_json,
            actor_membership_id: actor.id
          }
        )
      end

      Result.new(invoice: invoice, idempotent_replay: false)
    end
  end
end
