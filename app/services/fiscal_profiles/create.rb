module FiscalProfiles
  class Create
    def self.call!(organization:, actor:, attributes:)
      profile = nil

      ActiveRecord::Base.transaction do
        profile = organization.fiscal_profiles.create!(attributes)

        Auditing::Logger.log!(
          organization: organization,
          membership: actor,
          auditable: profile,
          action: "fiscal_profile.created",
          metadata: { fiscal_profile_id: profile.id, tax_id: profile.tax_id }
        )

        Events::Publisher.publish!(
          organization: organization,
          aggregate: profile,
          event_type: "fiscal_profile.created",
          payload: { fiscal_profile: profile.as_api_json, actor_membership_id: actor.id }
        )
      end

      profile
    end
  end
end
