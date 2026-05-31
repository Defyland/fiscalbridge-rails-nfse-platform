class Session < ApplicationRecord
  EXPIRES_IN = 12.hours
  REFRESH_INTERVAL = 10.minutes
  MAX_ACTIVE_SESSIONS_PER_USER = 5

  belongs_to :user

  before_validation :set_expiration, on: :create

  validates :user, presence: true
  validates :expires_at, presence: true

  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  def expired?
    expires_at <= Time.current
  end

  def refresh_if_stale!
    return false if last_seen_at.present? && last_seen_at > REFRESH_INTERVAL.ago

    update_columns(
      last_seen_at: Time.current,
      expires_at: EXPIRES_IN.from_now,
      updated_at: Time.current
    )
    true
  end

  def matches_request?(request)
    user_agent.blank? || user_agent == request.user_agent.to_s
  end

  private

  def set_expiration
    self.expires_at ||= EXPIRES_IN.from_now
    self.last_seen_at ||= Time.current
  end
end
