class ApplicationController < ActionController::Base
  before_action :resume_session
  after_action :set_observability_headers

  helper_method :authenticated?, :current_user, :current_membership, :current_organization

  rescue_from Security::RateLimitExceeded, with: :render_web_rate_limit

  private

  def require_authentication
    return if authenticated?

    redirect_to new_session_path, alert: "Entre para acessar o backoffice."
  end

  def resume_session
    session_record = Session.includes(user: { membership: :organization }).find_by(id: cookies.signed[:session_id])

    if session_record.nil?
      clear_current_session
      return
    end

    if session_record.expired? || !session_record.user.active? || !session_record.matches_request?(request)
      session_record.destroy
      cookies.delete(:session_id)
      clear_current_session
      return
    end

    Current.session = session_record
    Current.user = session_record.user
    Current.membership = Current.user.membership
    Current.organization = Current.membership.organization
    renew_session_cookie(session_record) if session_record.refresh_if_stale!
  end

  def authenticated?
    Current.user.present? && Current.session.present?
  end

  def current_user
    Current.user
  end

  def current_membership
    Current.membership
  end

  def current_organization
    Current.organization
  end

  def start_new_session_for(user)
    reset_session

    session_record = user.sessions.create!(
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )

    renew_session_cookie(session_record)

    Current.session = session_record
    Current.user = user
    Current.membership = user.membership
    Current.organization = user.organization
    user.prune_sessions!(except: session_record)
  end

  def terminate_session
    Current.session&.destroy
    cookies.delete(:session_id)
    clear_current_session
  end

  def renew_session_cookie(session_record)
    cookies.signed[:session_id] = {
      value: session_record.id,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?,
      expires: session_record.expires_at
    }
  end

  def clear_current_session
    Current.session = nil
    Current.user = nil
    Current.membership = nil
    Current.organization = nil
  end

  def set_observability_headers
    response.set_header("X-Request-ID", Current.request_id || request.request_id)
    response.set_header("X-Correlation-ID", Current.correlation_id) if Current.correlation_id.present?
  end

  def render_web_rate_limit(error)
    response.set_header("Retry-After", error.retry_after.to_s)
    redirect_to new_session_path, alert: "Muitas tentativas. Tente novamente em #{error.retry_after} segundos."
  end
end
