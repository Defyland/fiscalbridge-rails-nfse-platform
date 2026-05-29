module V1
  class FiscalProfilesController < ApplicationController
    def index
      authorize!(:fiscal_profiles_list)

      render json: { fiscal_profiles: current_organization.fiscal_profiles.ordered.map(&:as_api_json) }
    end

    def create
      authorize!(:fiscal_profiles_create)

      profile = current_organization.fiscal_profiles.create!(fiscal_profile_params)

      Auditing::Logger.log!(
        organization: current_organization,
        membership: current_membership,
        auditable: profile,
        action: "fiscal_profile.created",
        metadata: { fiscal_profile_id: profile.id, tax_id: profile.tax_id }
      )

      Events::Publisher.publish!(
        organization: current_organization,
        aggregate: profile,
        event_type: "fiscal_profile.created",
        payload: { fiscal_profile: profile.as_api_json, actor_membership_id: current_membership.id }
      )

      render json: { fiscal_profile: profile.as_api_json }, status: :created
    end

    def show
      authorize!(:fiscal_profiles_read)

      profile = current_organization.fiscal_profiles.find(params[:id])
      render json: { fiscal_profile: profile.as_api_json }
    end

    def update
      authorize!(:fiscal_profiles_update)

      profile = current_organization.fiscal_profiles.find(params[:id])
      profile.update!(fiscal_profile_params)

      Auditing::Logger.log!(
        organization: current_organization,
        membership: current_membership,
        auditable: profile,
        action: "fiscal_profile.updated",
        metadata: { changes: profile.saved_changes.except("updated_at") }
      )

      Events::Publisher.publish!(
        organization: current_organization,
        aggregate: profile,
        event_type: "fiscal_profile.updated",
        payload: { fiscal_profile: profile.as_api_json, actor_membership_id: current_membership.id }
      )

      render json: { fiscal_profile: profile.as_api_json }
    end

    private

    def fiscal_profile_params
      params.require(:fiscal_profile).permit(
        :legal_name,
        :trade_name,
        :tax_id,
        :municipal_registration,
        :city_code,
        :service_list_item,
        :taxation_regime,
        :environment,
        :default_profile
      )
    end
  end
end
