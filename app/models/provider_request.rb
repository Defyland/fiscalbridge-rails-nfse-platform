class ProviderRequest < ApplicationRecord
  belongs_to :organization
  belongs_to :service_invoice

  enum :action, {
    issue: "issue",
    cancel: "cancel",
    status_poll: "status_poll",
    callback: "callback"
  }, validate: true

  enum :status, {
    pending: "pending",
    succeeded: "succeeded",
    failed: "failed",
    duplicate: "duplicate"
  }, validate: true

  validates :provider_name, :action, :status, :idempotency_key, :correlation_id, presence: true
  validates :idempotency_key, uniqueness: true

  scope :recent_first, -> { order(created_at: :desc) }
end
