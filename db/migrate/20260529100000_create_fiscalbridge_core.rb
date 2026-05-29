class CreateFiscalbridgeCore < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :legal_name
      t.string :tax_id
      t.string :municipal_registration
      t.string :plan, null: false, default: "starter"
      t.string :state, null: false, default: "active"
      t.integer :seat_limit, null: false, default: 5
      t.integer :monthly_invoice_limit, null: false, default: 500
      t.integer :current_month_invoice_count, null: false, default: 0
      t.integer :next_invoice_sequence, null: false, default: 1

      t.timestamps
    end

    add_index :organizations, :slug, unique: true
    add_check_constraint :organizations, "seat_limit > 0", name: "organizations_seat_limit_positive"
    add_check_constraint :organizations, "monthly_invoice_limit > 0", name: "organizations_monthly_invoice_limit_positive"
    add_check_constraint :organizations, "current_month_invoice_count >= 0",
                         name: "organizations_current_month_invoice_count_non_negative"
    add_check_constraint :organizations, "next_invoice_sequence > 0", name: "organizations_next_invoice_sequence_positive"
    add_check_constraint :organizations, "plan IN ('starter', 'growth', 'enterprise')", name: "organizations_plan_valid"
    add_check_constraint :organizations, "state IN ('active', 'suspended')", name: "organizations_state_valid"

    create_table :memberships do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :email, null: false
      t.string :full_name, null: false
      t.string :role, null: false, default: "operator"
      t.string :state, null: false, default: "active"
      t.string :api_token_digest, null: false
      t.string :api_token_last_eight, null: false
      t.datetime :api_token_expires_at, null: false
      t.datetime :api_token_revoked_at
      t.datetime :last_seen_at

      t.timestamps
    end

    add_index :memberships, [ :organization_id, :email ], unique: true
    add_index :memberships, [ :organization_id, :role ]
    add_index :memberships, :api_token_digest, unique: true
    add_index :memberships, :api_token_expires_at
    add_check_constraint :memberships, "role IN ('owner', 'admin', 'operator', 'auditor')", name: "memberships_role_valid"
    add_check_constraint :memberships, "state IN ('active', 'suspended')", name: "memberships_state_valid"
    add_check_constraint :memberships, "length(api_token_last_eight) = 8", name: "memberships_token_last_eight_length"
    add_check_constraint :memberships, "api_token_expires_at > created_at",
                         name: "memberships_api_token_expires_after_creation"
    add_check_constraint :memberships, "api_token_revoked_at IS NULL OR api_token_revoked_at >= created_at",
                         name: "memberships_api_token_revoked_after_creation"

    create_table :fiscal_profiles do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :legal_name, null: false
      t.string :trade_name
      t.string :tax_id, null: false
      t.string :municipal_registration, null: false
      t.string :city_code, null: false
      t.string :service_list_item, null: false
      t.string :taxation_regime, null: false, default: "simples_nacional"
      t.string :environment, null: false, default: "sandbox"
      t.boolean :default_profile, null: false, default: false

      t.timestamps
    end

    add_index :fiscal_profiles, [ :organization_id, :tax_id ], unique: true
    add_index :fiscal_profiles, [ :organization_id, :default_profile ]
    add_check_constraint :fiscal_profiles, "taxation_regime IN ('simples_nacional', 'lucro_presumido', 'lucro_real')",
                         name: "fiscal_profiles_taxation_regime_valid"
    add_check_constraint :fiscal_profiles, "environment IN ('sandbox', 'production')",
                         name: "fiscal_profiles_environment_valid"

    create_table :customers do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :legal_name, null: false
      t.string :document_type, null: false
      t.string :document_number, null: false
      t.string :email
      t.string :city_code, null: false
      t.string :address_line
      t.string :state_code
      t.string :country_code, null: false, default: "BR"

      t.timestamps
    end

    add_index :customers, [ :organization_id, :document_number ], unique: true
    add_index :customers, [ :organization_id, :legal_name ]
    add_check_constraint :customers, "document_type IN ('cnpj', 'cpf', 'foreign')", name: "customers_document_type_valid"

    create_table :service_invoices do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :fiscal_profile, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.references :created_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.string :public_id, null: false
      t.string :idempotency_key, null: false
      t.string :status, null: false, default: "draft"
      t.text :service_description, null: false
      t.string :service_code, null: false
      t.integer :amount_cents, null: false
      t.integer :tax_rate_bps, null: false, default: 0
      t.boolean :iss_withheld, null: false, default: false
      t.string :provider_invoice_number
      t.string :provider_verification_code
      t.string :provider_protocol
      t.text :rejection_reason
      t.text :cancellation_reason
      t.string :xml_url
      t.string :pdf_url
      t.datetime :issued_at
      t.datetime :cancelled_at
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :service_invoices, [ :organization_id, :public_id ], unique: true
    add_index :service_invoices, [ :organization_id, :idempotency_key ], unique: true
    add_index :service_invoices, [ :organization_id, :status ]
    add_index :service_invoices, :provider_invoice_number, unique: true
    add_check_constraint :service_invoices, "amount_cents > 0", name: "service_invoices_amount_positive"
    add_check_constraint :service_invoices, "tax_rate_bps >= 0 AND tax_rate_bps <= 5000",
                         name: "service_invoices_tax_rate_valid"
    add_check_constraint :service_invoices,
                         "status IN ('draft', 'pending_issue', 'issued', 'rejected', 'pending_cancellation', 'cancelled', 'cancellation_failed')",
                         name: "service_invoices_status_valid"
    add_check_constraint :service_invoices, "lock_version >= 0", name: "service_invoices_lock_version_non_negative"

    create_table :provider_requests do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :service_invoice, null: false, foreign_key: true
      t.string :provider_name, null: false
      t.string :action, null: false
      t.string :status, null: false, default: "pending"
      t.json :request_payload, null: false, default: {}
      t.json :response_payload, null: false, default: {}
      t.text :error_message
      t.string :idempotency_key, null: false
      t.string :correlation_id, null: false
      t.datetime :responded_at

      t.timestamps
    end

    add_index :provider_requests, :idempotency_key, unique: true
    add_index :provider_requests, [ :organization_id, :status ]
    add_index :provider_requests, [ :service_invoice_id, :action, :status ]
    add_check_constraint :provider_requests, "action IN ('issue', 'cancel', 'status_poll', 'callback')",
                         name: "provider_requests_action_valid"
    add_check_constraint :provider_requests, "status IN ('pending', 'succeeded', 'failed', 'duplicate')",
                         name: "provider_requests_status_valid"

    create_table :audit_logs do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :membership, null: true, foreign_key: true
      t.references :auditable, null: false, polymorphic: true
      t.string :action, null: false
      t.json :metadata, null: false, default: {}
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_index :audit_logs, [ :organization_id, :created_at ]

    create_table :outbound_events do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :aggregate_type, null: false
      t.integer :aggregate_id, null: false
      t.string :event_type, null: false
      t.json :payload, null: false, default: {}
      t.string :idempotency_key, null: false
      t.string :correlation_id, null: false
      t.string :status, null: false, default: "pending"
      t.integer :attempts_count, null: false, default: 0
      t.text :last_error
      t.datetime :processing_started_at
      t.datetime :dispatched_at
      t.datetime :next_attempt_at

      t.timestamps
    end

    add_index :outbound_events, :idempotency_key, unique: true
    add_index :outbound_events, [ :organization_id, :status ]
    add_index :outbound_events, [ :status, :next_attempt_at ]
    add_check_constraint :outbound_events, "attempts_count >= 0", name: "outbound_events_attempts_count_non_negative"
    add_check_constraint :outbound_events, "status IN ('pending', 'processing', 'dispatched', 'failed')",
                         name: "outbound_events_status_valid"
    add_check_constraint :outbound_events, "next_attempt_at IS NULL OR status = 'pending'",
                         name: "outbound_events_next_attempt_only_pending"
  end
end
