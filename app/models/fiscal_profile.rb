class FiscalProfile < ApplicationRecord
  belongs_to :organization
  has_many :service_invoices, dependent: :restrict_with_exception
  has_many :audit_logs, as: :auditable, dependent: :destroy

  enum :taxation_regime, {
    simples_nacional: "simples_nacional",
    lucro_presumido: "lucro_presumido",
    lucro_real: "lucro_real"
  }, validate: true

  enum :environment, {
    sandbox: "sandbox",
    production: "production"
  }, validate: true

  before_validation :normalize_tax_id

  validates :legal_name, :tax_id, :municipal_registration, :city_code, :service_list_item, presence: true
  validates :tax_id, format: { with: /\A\d{14}\z/ }, uniqueness: { scope: :organization_id }
  validates :city_code, format: { with: /\A\d{7}\z/ }

  scope :ordered, -> { order(default_profile: :desc, legal_name: :asc) }

  def as_api_json
    {
      id: id,
      legal_name: legal_name,
      trade_name: trade_name,
      tax_id: tax_id,
      municipal_registration: municipal_registration,
      city_code: city_code,
      service_list_item: service_list_item,
      taxation_regime: taxation_regime,
      environment: environment,
      default_profile: default_profile,
      created_at: created_at&.iso8601,
      updated_at: updated_at&.iso8601
    }
  end

  private

  def normalize_tax_id
    self.tax_id = tax_id.to_s.gsub(/\D/, "") if tax_id.present?
  end
end
