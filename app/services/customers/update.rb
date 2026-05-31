module Customers
  class Update
    def self.call!(customer:, actor:, attributes:)
      ActiveRecord::Base.transaction do
        customer.update!(attributes)

        Auditing::Logger.log!(
          organization: customer.organization,
          membership: actor,
          auditable: customer,
          action: "customer.updated",
          metadata: { changes: customer.saved_changes.except("updated_at") }
        )

        Events::Publisher.publish!(
          organization: customer.organization,
          aggregate: customer,
          event_type: "customer.updated",
          payload: { customer: customer.as_api_json, actor_membership_id: actor.id }
        )
      end

      customer
    end
  end
end
