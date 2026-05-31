module Backoffice
  class FiscalProfilesController < BaseController
    def index
      authorize!(:fiscal_profiles_list)

      @fiscal_profiles = current_organization.fiscal_profiles.ordered.limit(100)
    end
  end
end
