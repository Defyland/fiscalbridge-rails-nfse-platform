class Organization < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :fiscal_profiles, dependent: :destroy
  has_many :customers, dependent: :destroy
  has_many :service_invoices, dependent: :destroy
  has_many :provider_requests, dependent: :destroy
  has_many :audit_logs, dependent: :destroy
  has_many :outbound_events, dependent: :destroy

  enum :plan, {
    starter: "starter",
    growth: "growth",
    enterprise: "enterprise"
  }, validate: true

  enum :state, {
    active: "active",
    suspended: "suspended"
  }, validate: true

  before_validation :normalize_slug

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :tax_id, allow_blank: true, format: { with: /\A\d{14}\z/ }
  validates :seat_limit, numericality: { greater_than: 0 }
  validates :monthly_invoice_limit, numericality: { greater_than: 0 }
  validates :current_month_invoice_count, numericality: { greater_than_or_equal_to: 0 }
  validates :next_invoice_sequence, numericality: { greater_than: 0 }

  def seat_available?
    memberships.active.count < seat_limit
  end

  def invoice_quota_available?
    current_month_invoice_count < monthly_invoice_limit
  end

  def as_api_json
    {
      id: id,
      name: name,
      slug: slug,
      legal_name: legal_name,
      tax_id: tax_id,
      municipal_registration: municipal_registration,
      plan: plan,
      state: state,
      seat_limit: seat_limit,
      monthly_invoice_limit: monthly_invoice_limit,
      current_month_invoice_count: current_month_invoice_count,
      next_invoice_sequence: next_invoice_sequence,
      created_at: created_at&.iso8601,
      updated_at: updated_at&.iso8601
    }
  end

  private

  def normalize_slug
    self.slug = slug.to_s.parameterize if slug.present?
    self.tax_id = tax_id.to_s.gsub(/\D/, "") if tax_id.present?
  end
end
