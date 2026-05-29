# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_29_100000) do
  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.integer "auditable_id", null: false
    t.string "auditable_type", null: false
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.integer "membership_id"
    t.json "metadata", default: {}, null: false
    t.integer "organization_id", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable"
    t.index ["membership_id"], name: "index_audit_logs_on_membership_id"
    t.index ["organization_id", "created_at"], name: "index_audit_logs_on_organization_id_and_created_at"
    t.index ["organization_id"], name: "index_audit_logs_on_organization_id"
  end

  create_table "customers", force: :cascade do |t|
    t.string "address_line"
    t.string "city_code", null: false
    t.string "country_code", default: "BR", null: false
    t.datetime "created_at", null: false
    t.string "document_number", null: false
    t.string "document_type", null: false
    t.string "email"
    t.string "legal_name", null: false
    t.integer "organization_id", null: false
    t.string "state_code"
    t.datetime "updated_at", null: false
    t.index ["organization_id", "document_number"], name: "index_customers_on_organization_id_and_document_number", unique: true
    t.index ["organization_id", "legal_name"], name: "index_customers_on_organization_id_and_legal_name"
    t.index ["organization_id"], name: "index_customers_on_organization_id"
    t.check_constraint "document_type IN ('cnpj', 'cpf', 'foreign')", name: "customers_document_type_valid"
  end

  create_table "fiscal_profiles", force: :cascade do |t|
    t.string "city_code", null: false
    t.datetime "created_at", null: false
    t.boolean "default_profile", default: false, null: false
    t.string "environment", default: "sandbox", null: false
    t.string "legal_name", null: false
    t.string "municipal_registration", null: false
    t.integer "organization_id", null: false
    t.string "service_list_item", null: false
    t.string "tax_id", null: false
    t.string "taxation_regime", default: "simples_nacional", null: false
    t.string "trade_name"
    t.datetime "updated_at", null: false
    t.index ["organization_id", "default_profile"], name: "index_fiscal_profiles_on_organization_id_and_default_profile"
    t.index ["organization_id", "tax_id"], name: "index_fiscal_profiles_on_organization_id_and_tax_id", unique: true
    t.index ["organization_id"], name: "index_fiscal_profiles_on_organization_id"
    t.check_constraint "environment IN ('sandbox', 'production')", name: "fiscal_profiles_environment_valid"
    t.check_constraint "taxation_regime IN ('simples_nacional', 'lucro_presumido', 'lucro_real')", name: "fiscal_profiles_taxation_regime_valid"
  end

  create_table "memberships", force: :cascade do |t|
    t.string "api_token_digest", null: false
    t.datetime "api_token_expires_at", null: false
    t.string "api_token_last_eight", null: false
    t.datetime "api_token_revoked_at"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "full_name", null: false
    t.datetime "last_seen_at"
    t.integer "organization_id", null: false
    t.string "role", default: "operator", null: false
    t.string "state", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["api_token_digest"], name: "index_memberships_on_api_token_digest", unique: true
    t.index ["api_token_expires_at"], name: "index_memberships_on_api_token_expires_at"
    t.index ["organization_id", "email"], name: "index_memberships_on_organization_id_and_email", unique: true
    t.index ["organization_id", "role"], name: "index_memberships_on_organization_id_and_role"
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
    t.check_constraint "api_token_expires_at > created_at", name: "memberships_api_token_expires_after_creation"
    t.check_constraint "api_token_revoked_at IS NULL OR api_token_revoked_at >= created_at", name: "memberships_api_token_revoked_after_creation"
    t.check_constraint "length(api_token_last_eight) = 8", name: "memberships_token_last_eight_length"
    t.check_constraint "role IN ('owner', 'admin', 'operator', 'auditor')", name: "memberships_role_valid"
    t.check_constraint "state IN ('active', 'suspended')", name: "memberships_state_valid"
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "current_month_invoice_count", default: 0, null: false
    t.string "legal_name"
    t.integer "monthly_invoice_limit", default: 500, null: false
    t.string "municipal_registration"
    t.string "name", null: false
    t.integer "next_invoice_sequence", default: 1, null: false
    t.string "plan", default: "starter", null: false
    t.integer "seat_limit", default: 5, null: false
    t.string "slug", null: false
    t.string "state", default: "active", null: false
    t.string "tax_id"
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
    t.check_constraint "current_month_invoice_count >= 0", name: "organizations_current_month_invoice_count_non_negative"
    t.check_constraint "monthly_invoice_limit > 0", name: "organizations_monthly_invoice_limit_positive"
    t.check_constraint "next_invoice_sequence > 0", name: "organizations_next_invoice_sequence_positive"
    t.check_constraint "plan IN ('starter', 'growth', 'enterprise')", name: "organizations_plan_valid"
    t.check_constraint "seat_limit > 0", name: "organizations_seat_limit_positive"
    t.check_constraint "state IN ('active', 'suspended')", name: "organizations_state_valid"
  end

  create_table "outbound_events", force: :cascade do |t|
    t.integer "aggregate_id", null: false
    t.string "aggregate_type", null: false
    t.integer "attempts_count", default: 0, null: false
    t.string "correlation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "dispatched_at"
    t.string "event_type", null: false
    t.string "idempotency_key", null: false
    t.text "last_error"
    t.datetime "next_attempt_at"
    t.integer "organization_id", null: false
    t.json "payload", default: {}, null: false
    t.datetime "processing_started_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_outbound_events_on_idempotency_key", unique: true
    t.index ["organization_id", "status"], name: "index_outbound_events_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_outbound_events_on_organization_id"
    t.index ["status", "next_attempt_at"], name: "index_outbound_events_on_status_and_next_attempt_at"
    t.check_constraint "attempts_count >= 0", name: "outbound_events_attempts_count_non_negative"
    t.check_constraint "next_attempt_at IS NULL OR status = 'pending'", name: "outbound_events_next_attempt_only_pending"
    t.check_constraint "status IN ('pending', 'processing', 'dispatched', 'failed')", name: "outbound_events_status_valid"
  end

  create_table "provider_requests", force: :cascade do |t|
    t.string "action", null: false
    t.string "correlation_id", null: false
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "idempotency_key", null: false
    t.integer "organization_id", null: false
    t.string "provider_name", null: false
    t.json "request_payload", default: {}, null: false
    t.datetime "responded_at"
    t.json "response_payload", default: {}, null: false
    t.integer "service_invoice_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_provider_requests_on_idempotency_key", unique: true
    t.index ["organization_id", "status"], name: "index_provider_requests_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_provider_requests_on_organization_id"
    t.index ["service_invoice_id", "action", "status"], name: "idx_on_service_invoice_id_action_status_57250f2e91"
    t.index ["service_invoice_id"], name: "index_provider_requests_on_service_invoice_id"
    t.check_constraint "action IN ('issue', 'cancel', 'status_poll', 'callback')", name: "provider_requests_action_valid"
    t.check_constraint "status IN ('pending', 'succeeded', 'failed', 'duplicate')", name: "provider_requests_status_valid"
  end

  create_table "service_invoices", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.text "cancellation_reason"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.integer "created_by_membership_id", null: false
    t.integer "customer_id", null: false
    t.integer "fiscal_profile_id", null: false
    t.string "idempotency_key", null: false
    t.boolean "iss_withheld", default: false, null: false
    t.datetime "issued_at"
    t.integer "lock_version", default: 0, null: false
    t.integer "organization_id", null: false
    t.string "pdf_url"
    t.string "provider_invoice_number"
    t.string "provider_protocol"
    t.string "provider_verification_code"
    t.string "public_id", null: false
    t.text "rejection_reason"
    t.string "service_code", null: false
    t.text "service_description", null: false
    t.string "status", default: "draft", null: false
    t.integer "tax_rate_bps", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "xml_url"
    t.index ["created_by_membership_id"], name: "index_service_invoices_on_created_by_membership_id"
    t.index ["customer_id"], name: "index_service_invoices_on_customer_id"
    t.index ["fiscal_profile_id"], name: "index_service_invoices_on_fiscal_profile_id"
    t.index ["organization_id", "idempotency_key"], name: "index_service_invoices_on_organization_id_and_idempotency_key", unique: true
    t.index ["organization_id", "public_id"], name: "index_service_invoices_on_organization_id_and_public_id", unique: true
    t.index ["organization_id", "status"], name: "index_service_invoices_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_service_invoices_on_organization_id"
    t.index ["provider_invoice_number"], name: "index_service_invoices_on_provider_invoice_number", unique: true
    t.check_constraint "amount_cents > 0", name: "service_invoices_amount_positive"
    t.check_constraint "lock_version >= 0", name: "service_invoices_lock_version_non_negative"
    t.check_constraint "status IN ('draft', 'pending_issue', 'issued', 'rejected', 'pending_cancellation', 'cancelled', 'cancellation_failed')", name: "service_invoices_status_valid"
    t.check_constraint "tax_rate_bps >= 0 AND tax_rate_bps <= 5000", name: "service_invoices_tax_rate_valid"
  end

  add_foreign_key "audit_logs", "memberships"
  add_foreign_key "audit_logs", "organizations"
  add_foreign_key "customers", "organizations"
  add_foreign_key "fiscal_profiles", "organizations"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "outbound_events", "organizations"
  add_foreign_key "provider_requests", "organizations"
  add_foreign_key "provider_requests", "service_invoices"
  add_foreign_key "service_invoices", "customers"
  add_foreign_key "service_invoices", "fiscal_profiles"
  add_foreign_key "service_invoices", "memberships", column: "created_by_membership_id"
  add_foreign_key "service_invoices", "organizations"
end
