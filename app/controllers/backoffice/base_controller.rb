module Backoffice
  class BaseController < ApplicationController
    before_action :require_authentication
    before_action :ensure_active_user!

    rescue_from ActiveRecord::RecordNotFound do
      redirect_to dashboard_path, alert: "Registro nao encontrado."
    end

    rescue_from ActionController::ParameterMissing, ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError,
                Invoices::InvalidTransition,
                Security::AuthorizationError do |error|
      redirect_back fallback_location: dashboard_path, alert: error.message
    end

    private

    def ensure_active_user!
      return unless authenticated?
      return if current_user.active?

      terminate_session
      redirect_to new_session_path, alert: "Usuario suspenso."
    end

    def authorize!(permission)
      Security::Authorizer.authorize!(current_membership, permission)
    end
  end
end
