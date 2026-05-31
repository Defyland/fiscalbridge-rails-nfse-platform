class User < ApplicationRecord
  has_secure_password

  belongs_to :membership
  has_many :sessions, dependent: :destroy

  delegate :organization, :role, to: :membership

  before_validation :normalize_email_address

  validates :email_address, presence: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP },
                            uniqueness: true
  validates :membership_id, uniqueness: true

  scope :ordered, -> { order(:email_address) }

  def active?
    membership.active?
  end

  def touch_last_seen!
    update_column(:last_seen_at, Time.current)
  end

  def prune_sessions!(except:)
    sessions.expired.delete_all

    retained_session_ids = sessions.active
                                   .where.not(id: except.id)
                                   .order(created_at: :desc)
                                   .limit(Session::MAX_ACTIVE_SESSIONS_PER_USER - 1)
                                   .pluck(:id)
    sessions.active.where.not(id: [ except.id, *retained_session_ids ]).delete_all
  end

  private

  def normalize_email_address
    self.email_address = email_address.to_s.strip.downcase if email_address.present?
  end
end
