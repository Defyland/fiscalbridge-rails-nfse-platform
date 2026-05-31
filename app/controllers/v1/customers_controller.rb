module V1
  class CustomersController < ApiController
    def index
      authorize!(:customers_list)
      customers, pagination = bounded_page(current_organization.customers.order(id: :asc))
      return if performed?

      render json: { customers: customers.map(&:as_api_json), pagination: pagination }
    end

    def create
      authorize!(:customers_create)

      customer = Customers::Create.call!(
        organization: current_organization,
        actor: current_membership,
        attributes: customer_params
      )

      render json: { customer: customer.as_api_json }, status: :created
    end

    def show
      authorize!(:customers_read)

      customer = current_organization.customers.find(params[:id])
      render json: { customer: customer.as_api_json }
    end

    def update
      authorize!(:customers_update)

      customer = current_organization.customers.find(params[:id])
      Customers::Update.call!(customer: customer, actor: current_membership, attributes: customer_params)

      render json: { customer: customer.as_api_json }
    end

    private

    def customer_params
      params.require(:customer).permit(
        :legal_name,
        :document_type,
        :document_number,
        :email,
        :city_code,
        :address_line,
        :state_code,
        :country_code
      )
    end
  end
end
