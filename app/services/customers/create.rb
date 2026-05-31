module Customers
  class Create
    def self.call!(organization:, actor:, attributes:)
      customer = nil

      ActiveRecord::Base.transaction do
        customer = organization.customers.create!(attributes)

        Auditing::Logger.log!(
          organization: organization,
          membership: actor,
          auditable: customer,
          action: "customer.created",
          metadata: { customer_id: customer.id, document_number: customer.document_number }
        )

        Events::Publisher.publish!(
          organization: organization,
          aggregate: customer,
          event_type: "customer.created",
          payload: { customer: customer.as_api_json, actor_membership_id: actor.id }
        )
      end

      customer
    end
  end
end
