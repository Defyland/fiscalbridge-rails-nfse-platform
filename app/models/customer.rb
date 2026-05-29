class Customer < ApplicationRecord
  belongs_to :organization
  has_many :service_invoices, dependent: :restrict_with_exception
  has_many :audit_logs, as: :auditable, dependent: :destroy

  enum :document_type, {
    cnpj: "cnpj",
    cpf: "cpf",
    foreign: "foreign"
  }, validate: true

  before_validation :normalize_document
  before_validation :normalize_email

  validates :legal_name, :document_type, :document_number, :city_code, presence: true
  validates :document_number, uniqueness: { scope: :organization_id }
  validates :email, allow_blank: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :city_code, format: { with: /\A\d{7}\z/ }, unless: :foreign?

  scope :ordered, -> { order(:legal_name) }

  def as_api_json
    {
      id: id,
      legal_name: legal_name,
      document_type: document_type,
      document_number: document_number,
      email: email,
      city_code: city_code,
      address_line: address_line,
      state_code: state_code,
      country_code: country_code,
      created_at: created_at&.iso8601,
      updated_at: updated_at&.iso8601
    }
  end

  private

  def normalize_document
    self.document_number = document_number.to_s.gsub(/\D/, "") if document_number.present? && !foreign?
  end

  def normalize_email
    self.email = email.to_s.strip.downcase if email.present?
  end
end
