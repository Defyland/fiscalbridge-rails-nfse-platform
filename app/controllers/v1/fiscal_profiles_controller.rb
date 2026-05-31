module V1
  class FiscalProfilesController < ApiController
    def index
      authorize!(:fiscal_profiles_list)
      profiles, pagination = bounded_page(current_organization.fiscal_profiles.order(id: :asc))
      return if performed?

      render json: { fiscal_profiles: profiles.map(&:as_api_json), pagination: pagination }
    end

    def create
      authorize!(:fiscal_profiles_create)

      profile = FiscalProfiles::Create.call!(
        organization: current_organization,
        actor: current_membership,
        attributes: fiscal_profile_params
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
      FiscalProfiles::Update.call!(profile: profile, actor: current_membership, attributes: fiscal_profile_params)

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
