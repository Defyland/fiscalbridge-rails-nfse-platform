module Backoffice
  class CustomersController < BaseController
    def index
      authorize!(:customers_list)

      @customers = current_organization.customers.ordered.limit(100)
    end
  end
end
