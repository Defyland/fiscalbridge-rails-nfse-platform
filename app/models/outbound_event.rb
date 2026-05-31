class OutboundEvent < ApplicationRecord
  PROCESSING_TIMEOUT = 10.minutes

  belongs_to :organization

  enum :status, {
    pending: "pending",
    processing: "processing",
    dispatched: "dispatched",
    failed: "failed"
  }, validate: true

  validates :aggregate_type, :aggregate_id, :event_type, :idempotency_key, :correlation_id, presence: true
  validates :idempotency_key, uniqueness: true

  scope :due_for_dispatch, -> {
    where(status: "pending").where("next_attempt_at IS NULL OR next_attempt_at <= ?", Time.current)
                            .or(
                              where(status: "processing")
                                .where("processing_started_at IS NULL OR processing_started_at <= ?",
                                       PROCESSING_TIMEOUT.ago)
                            )
                            .order(:created_at)
  }
end
