class SessionsController < ApplicationController
  before_action :require_authentication, only: :destroy

  def new
    redirect_to dashboard_path if authenticated?
  end

  def create
    email_address = params[:email_address].to_s.strip.downcase
    Security::RateLimiter.check!("login:#{request.remote_ip}:#{email_address.presence || 'blank'}")

    user = User.includes(membership: :organization).find_by(email_address: email_address)

    if user&.authenticate(params[:password]) && user.active?
      start_new_session_for(user)
      user.touch_last_seen!
      redirect_to dashboard_path
    else
      flash.now[:alert] = "Credenciais invalidas ou usuario suspenso."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, notice: "Sessao encerrada."
  end
end
