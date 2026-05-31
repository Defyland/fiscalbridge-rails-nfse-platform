class ServiceInvoice < ApplicationRecord
  SHA256_HEX_PATTERN = /\A[0-9a-f]{64}\z/

  belongs_to :organization
  belongs_to :fiscal_profile
  belongs_to :customer
  belongs_to :created_by_membership, class_name: "Membership", inverse_of: :created_service_invoices
  has_many :provider_requests, dependent: :destroy
  has_many :audit_logs, as: :auditable, dependent: :destroy
  has_one_attached :xml_file
  has_one_attached :pdf_file

  enum :status, {
    draft: "draft",
    pending_issue: "pending_issue",
    issued: "issued",
    rejected: "rejected",
    pending_cancellation: "pending_cancellation",
    cancelled: "cancelled",
    cancellation_failed: "cancellation_failed"
  }, validate: true

  before_validation :normalize_idempotency_key

  validates :public_id, :idempotency_key, :service_description, :service_code, presence: true
  validates :public_id, uniqueness: { scope: :organization_id }
  validates :idempotency_key, uniqueness: { scope: :organization_id }
  validates :amount_cents, numericality: { greater_than: 0 }
  validates :tax_rate_bps, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5000 }
  validates :xml_sha256, :pdf_sha256, format: { with: SHA256_HEX_PATTERN }, allow_blank: true
  validate :associations_belong_to_organization

  scope :recent_first, -> { order(created_at: :desc) }

  def can_issue?
    draft? || rejected?
  end

  def can_cancel?
    issued?
  end

  def amount
    amount_cents.to_d / 100
  end

  def as_api_json(include_relationships: true)
    payload = {
      id: public_id,
      status: status,
      service_description: service_description,
      service_code: service_code,
      amount_cents: amount_cents,
      tax_rate_bps: tax_rate_bps,
      iss_withheld: iss_withheld,
      idempotency_key: idempotency_key,
      provider_invoice_number: provider_invoice_number,
      provider_verification_code: provider_verification_code,
      provider_protocol: provider_protocol,
      rejection_reason: rejection_reason,
      cancellation_reason: cancellation_reason,
      xml_url: xml_url,
      pdf_url: pdf_url,
      xml_sha256: xml_sha256,
      pdf_sha256: pdf_sha256,
      lock_version: lock_version,
      issued_at: issued_at&.iso8601,
      cancelled_at: cancelled_at&.iso8601,
      evidence_recorded_at: evidence_recorded_at&.iso8601,
      created_at: created_at&.iso8601,
      updated_at: updated_at&.iso8601
    }

    return payload unless include_relationships

    payload.merge(
      fiscal_profile: fiscal_profile.as_api_json,
      customer: customer.as_api_json,
      created_by: created_by_membership.as_api_json
    )
  end

  private

  def normalize_idempotency_key
    self.idempotency_key = idempotency_key.to_s.strip if idempotency_key.present?
  end

  def associations_belong_to_organization
    return if organization.blank?

    if fiscal_profile.present? && fiscal_profile.organization_id != organization_id
      errors.add(:fiscal_profile, "must belong to the same organization")
    end

    if customer.present? && customer.organization_id != organization_id
      errors.add(:customer, "must belong to the same organization")
    end

    if created_by_membership.present? && created_by_membership.organization_id != organization_id
      errors.add(:created_by_membership, "must belong to the same organization")
    end
  end
end
