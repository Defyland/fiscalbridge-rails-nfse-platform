module V1
  class CustomersController < ApplicationController
    def index
      authorize!(:customers_list)

      render json: { customers: current_organization.customers.ordered.map(&:as_api_json) }
    end

    def create
      authorize!(:customers_create)

      customer = current_organization.customers.create!(customer_params)

      Auditing::Logger.log!(
        organization: current_organization,
        membership: current_membership,
        auditable: customer,
        action: "customer.created",
        metadata: { customer_id: customer.id, document_number: customer.document_number }
      )

      Events::Publisher.publish!(
        organization: current_organization,
        aggregate: customer,
        event_type: "customer.created",
        payload: { customer: customer.as_api_json, actor_membership_id: current_membership.id }
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
      customer.update!(customer_params)

      Auditing::Logger.log!(
        organization: current_organization,
        membership: current_membership,
        auditable: customer,
        action: "customer.updated",
        metadata: { changes: customer.saved_changes.except("updated_at") }
      )

      Events::Publisher.publish!(
        organization: current_organization,
        aggregate: customer,
        event_type: "customer.updated",
        payload: { customer: customer.as_api_json, actor_membership_id: current_membership.id }
      )

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
