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

ActiveRecord::Schema[8.1].define(version: 2026_05_29_164000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "auditable_id", null: false
    t.string "auditable_type", null: false
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.bigint "membership_id"
    t.json "metadata", default: {}, null: false
    t.bigint "organization_id", null: false
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
    t.bigint "organization_id", null: false
    t.string "state_code"
    t.datetime "updated_at", null: false
    t.index ["organization_id", "document_number"], name: "index_customers_on_organization_id_and_document_number", unique: true
    t.index ["organization_id", "legal_name"], name: "index_customers_on_organization_id_and_legal_name"
    t.index ["organization_id"], name: "index_customers_on_organization_id"
    t.check_constraint "document_type::text = ANY (ARRAY['cnpj'::character varying::text, 'cpf'::character varying::text, 'foreign'::character varying::text])", name: "customers_document_type_valid"
  end

  create_table "fiscal_profiles", force: :cascade do |t|
    t.string "city_code", null: false
    t.datetime "created_at", null: false
    t.boolean "default_profile", default: false, null: false
    t.string "environment", default: "sandbox", null: false
    t.string "legal_name", null: false
    t.string "municipal_registration", null: false
    t.bigint "organization_id", null: false
    t.string "service_list_item", null: false
    t.string "tax_id", null: false
    t.string "taxation_regime", default: "simples_nacional", null: false
    t.string "trade_name"
    t.datetime "updated_at", null: false
    t.index ["organization_id", "default_profile"], name: "index_fiscal_profiles_on_organization_id_and_default_profile"
    t.index ["organization_id", "tax_id"], name: "index_fiscal_profiles_on_organization_id_and_tax_id", unique: true
    t.index ["organization_id"], name: "index_fiscal_profiles_on_organization_id"
    t.check_constraint "environment::text = ANY (ARRAY['sandbox'::character varying::text, 'production'::character varying::text])", name: "fiscal_profiles_environment_valid"
    t.check_constraint "taxation_regime::text = ANY (ARRAY['simples_nacional'::character varying::text, 'lucro_presumido'::character varying::text, 'lucro_real'::character varying::text])", name: "fiscal_profiles_taxation_regime_valid"
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
    t.bigint "organization_id", null: false
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
    t.check_constraint "length(api_token_last_eight::text) = 8", name: "memberships_token_last_eight_length"
    t.check_constraint "role::text = ANY (ARRAY['owner'::character varying::text, 'admin'::character varying::text, 'operator'::character varying::text, 'auditor'::character varying::text])", name: "memberships_role_valid"
    t.check_constraint "state::text = ANY (ARRAY['active'::character varying::text, 'suspended'::character varying::text])", name: "memberships_state_valid"
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
    t.check_constraint "plan::text = ANY (ARRAY['starter'::character varying::text, 'growth'::character varying::text, 'enterprise'::character varying::text])", name: "organizations_plan_valid"
    t.check_constraint "seat_limit > 0", name: "organizations_seat_limit_positive"
    t.check_constraint "state::text = ANY (ARRAY['active'::character varying::text, 'suspended'::character varying::text])", name: "organizations_state_valid"
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
    t.bigint "organization_id", null: false
    t.json "payload", default: {}, null: false
    t.datetime "processing_started_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_outbound_events_on_idempotency_key", unique: true
    t.index ["organization_id", "status"], name: "index_outbound_events_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_outbound_events_on_organization_id"
    t.index ["status", "next_attempt_at"], name: "index_outbound_events_on_status_and_next_attempt_at"
    t.check_constraint "attempts_count >= 0", name: "outbound_events_attempts_count_non_negative"
    t.check_constraint "next_attempt_at IS NULL OR status::text = 'pending'::text", name: "outbound_events_next_attempt_only_pending"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'processing'::character varying::text, 'dispatched'::character varying::text, 'failed'::character varying::text])", name: "outbound_events_status_valid"
  end

  create_table "provider_requests", force: :cascade do |t|
    t.string "action", null: false
    t.string "correlation_id", null: false
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "idempotency_key", null: false
    t.bigint "organization_id", null: false
    t.string "provider_name", null: false
    t.json "request_payload", default: {}, null: false
    t.datetime "responded_at"
    t.json "response_payload", default: {}, null: false
    t.bigint "service_invoice_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_provider_requests_on_idempotency_key", unique: true
    t.index ["organization_id", "status"], name: "index_provider_requests_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_provider_requests_on_organization_id"
    t.index ["service_invoice_id", "action", "status"], name: "idx_on_service_invoice_id_action_status_57250f2e91"
    t.index ["service_invoice_id"], name: "index_provider_requests_on_service_invoice_id"
    t.check_constraint "action::text = ANY (ARRAY['issue'::character varying::text, 'cancel'::character varying::text, 'status_poll'::character varying::text, 'callback'::character varying::text])", name: "provider_requests_action_valid"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'succeeded'::character varying::text, 'failed'::character varying::text, 'duplicate'::character varying::text])", name: "provider_requests_status_valid"
  end

  create_table "service_invoices", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.text "cancellation_reason"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.bigint "created_by_membership_id", null: false
    t.bigint "customer_id", null: false
    t.datetime "evidence_recorded_at"
    t.bigint "fiscal_profile_id", null: false
    t.string "idempotency_key", null: false
    t.boolean "iss_withheld", default: false, null: false
    t.datetime "issued_at"
    t.integer "lock_version", default: 0, null: false
    t.bigint "organization_id", null: false
    t.string "pdf_sha256"
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
    t.string "xml_sha256"
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
    t.check_constraint "pdf_sha256 IS NULL OR pdf_sha256::text ~ '^[0-9a-f]{64}$'::text", name: "service_invoices_pdf_sha256_valid"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'pending_issue'::character varying::text, 'issued'::character varying::text, 'rejected'::character varying::text, 'pending_cancellation'::character varying::text, 'cancelled'::character varying::text, 'cancellation_failed'::character varying::text])", name: "service_invoices_status_valid"
    t.check_constraint "tax_rate_bps >= 0 AND tax_rate_bps <= 5000", name: "service_invoices_tax_rate_valid"
    t.check_constraint "xml_sha256 IS NULL OR xml_sha256::text ~ '^[0-9a-f]{64}$'::text", name: "service_invoices_xml_sha256_valid"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "ip_address"
    t.datetime "last_seen_at"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["created_at"], name: "index_sessions_on_created_at"
    t.index ["expires_at"], name: "index_sessions_on_expires_at"
    t.index ["user_id", "expires_at"], name: "index_sessions_on_user_id_and_expires_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.datetime "last_seen_at"
    t.bigint "membership_id", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["membership_id"], name: "index_users_on_membership_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
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
  add_foreign_key "sessions", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "users", "memberships"
end
