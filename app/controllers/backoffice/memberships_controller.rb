module Backoffice
  class MembershipsController < BaseController
    def index
      authorize!(:memberships_list)

      @memberships = current_organization.memberships.includes(:user).ordered
    end
  end
end
