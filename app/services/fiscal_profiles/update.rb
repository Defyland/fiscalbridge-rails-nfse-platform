module FiscalProfiles
  class Update
    def self.call!(profile:, actor:, attributes:)
      ActiveRecord::Base.transaction do
        profile.update!(attributes)

        Auditing::Logger.log!(
          organization: profile.organization,
          membership: actor,
          auditable: profile,
          action: "fiscal_profile.updated",
          metadata: { changes: profile.saved_changes.except("updated_at") }
        )

        Events::Publisher.publish!(
          organization: profile.organization,
          aggregate: profile,
          event_type: "fiscal_profile.updated",
          payload: { fiscal_profile: profile.as_api_json, actor_membership_id: actor.id }
        )
      end

      profile
    end
  end
end
