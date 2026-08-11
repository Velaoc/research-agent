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

ActiveRecord::Schema[8.1].define(version: 2026_08_11_140000) do
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

  create_table "crm_activities", force: :cascade do |t|
    t.bigint "actor_id"
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "organization_id", null: false
    t.string "summary", null: false
    t.bigint "trackable_id", null: false
    t.string "trackable_type", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_crm_activities_on_actor_id"
    t.index ["organization_id", "created_at"], name: "index_crm_activities_on_organization_id_and_created_at"
    t.index ["organization_id", "trackable_type", "trackable_id", "created_at"], name: "index_crm_activities_on_org_trackable"
    t.index ["organization_id"], name: "index_crm_activities_on_organization_id"
    t.check_constraint "length(btrim(kind::text)) > 0", name: "crm_activities_kind_present"
    t.check_constraint "length(btrim(summary::text)) > 0", name: "crm_activities_summary_present"
    t.check_constraint "trackable_type::text = ANY (ARRAY['Foundation::Crm::Contact'::character varying, 'Foundation::Crm::Company'::character varying, 'Foundation::Crm::Lead'::character varying, 'Foundation::Crm::Opportunity'::character varying, 'Foundation::Crm::Task'::character varying]::text[])", name: "crm_activities_trackable_type_allowed"
  end

  create_table "crm_companies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "domain"
    t.string "industry"
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.string "website"
    t.index ["organization_id", "domain"], name: "index_crm_companies_on_org_domain", unique: true, where: "((domain IS NOT NULL) AND (length(btrim((domain)::text)) > 0))"
    t.index ["organization_id", "name"], name: "index_crm_companies_on_organization_id_and_name"
    t.index ["organization_id"], name: "index_crm_companies_on_organization_id"
    t.check_constraint "length(btrim(name::text)) > 0", name: "crm_companies_name_present"
  end

  create_table "crm_contacts", force: :cascade do |t|
    t.bigint "company_id"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "first_name", default: "", null: false
    t.string "last_name", default: "", null: false
    t.bigint "organization_id", null: false
    t.bigint "owner_id"
    t.string "phone"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_crm_contacts_on_company_id"
    t.index ["organization_id", "email"], name: "index_crm_contacts_on_organization_id_and_email", where: "(email IS NOT NULL)"
    t.index ["organization_id", "last_name", "first_name"], name: "idx_on_organization_id_last_name_first_name_ac1191ba56"
    t.index ["organization_id", "owner_id"], name: "index_crm_contacts_on_organization_id_and_owner_id"
    t.index ["organization_id"], name: "index_crm_contacts_on_organization_id"
    t.index ["owner_id"], name: "index_crm_contacts_on_owner_id"
    t.check_constraint "length(btrim(first_name::text)) > 0 OR length(btrim(last_name::text)) > 0 OR length(btrim(COALESCE(email, ''::character varying)::text)) > 0", name: "crm_contacts_identity_present"
  end

  create_table "crm_leads", force: :cascade do |t|
    t.bigint "company_id"
    t.bigint "contact_id"
    t.datetime "created_at", null: false
    t.text "description", default: "", null: false
    t.string "email"
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.bigint "owner_id"
    t.string "phone"
    t.string "source"
    t.string "status", default: "new", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_crm_leads_on_company_id"
    t.index ["contact_id"], name: "index_crm_leads_on_contact_id"
    t.index ["organization_id", "created_at"], name: "index_crm_leads_on_organization_id_and_created_at"
    t.index ["organization_id", "owner_id"], name: "index_crm_leads_on_organization_id_and_owner_id"
    t.index ["organization_id", "status"], name: "index_crm_leads_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_crm_leads_on_organization_id"
    t.index ["owner_id"], name: "index_crm_leads_on_owner_id"
    t.check_constraint "length(btrim(name::text)) > 0", name: "crm_leads_name_present"
    t.check_constraint "status::text = ANY (ARRAY['new'::character varying, 'contacted'::character varying, 'qualified'::character varying, 'disqualified'::character varying, 'converted'::character varying]::text[])", name: "crm_leads_status_allowed"
  end

  create_table "crm_notes", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.bigint "notable_id", null: false
    t.string "notable_type", null: false
    t.bigint "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_crm_notes_on_author_id"
    t.index ["organization_id", "notable_type", "notable_id", "created_at"], name: "index_crm_notes_on_org_notable"
    t.index ["organization_id"], name: "index_crm_notes_on_organization_id"
    t.check_constraint "length(btrim(body)) > 0", name: "crm_notes_body_present"
    t.check_constraint "notable_type::text = ANY (ARRAY['Foundation::Crm::Contact'::character varying, 'Foundation::Crm::Company'::character varying, 'Foundation::Crm::Lead'::character varying, 'Foundation::Crm::Opportunity'::character varying]::text[])", name: "crm_notes_notable_type_allowed"
  end

  create_table "crm_opportunities", force: :cascade do |t|
    t.bigint "amount_cents", default: 0, null: false
    t.bigint "company_id"
    t.bigint "contact_id"
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "USD", null: false
    t.text "description", default: "", null: false
    t.date "expected_close_on"
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.bigint "owner_id"
    t.bigint "pipeline_id", null: false
    t.bigint "pipeline_stage_id", null: false
    t.string "status", default: "open", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_crm_opportunities_on_company_id"
    t.index ["contact_id"], name: "index_crm_opportunities_on_contact_id"
    t.index ["organization_id", "expected_close_on"], name: "idx_on_organization_id_expected_close_on_d92d7e1499"
    t.index ["organization_id", "owner_id"], name: "index_crm_opportunities_on_organization_id_and_owner_id"
    t.index ["organization_id", "pipeline_stage_id"], name: "idx_on_organization_id_pipeline_stage_id_c39b159e21"
    t.index ["organization_id", "status"], name: "index_crm_opportunities_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_crm_opportunities_on_organization_id"
    t.index ["owner_id"], name: "index_crm_opportunities_on_owner_id"
    t.index ["pipeline_id"], name: "index_crm_opportunities_on_pipeline_id"
    t.index ["pipeline_stage_id"], name: "index_crm_opportunities_on_pipeline_stage_id"
    t.check_constraint "amount_cents >= 0", name: "crm_opportunities_amount_nonnegative"
    t.check_constraint "currency::text = upper(currency::text) AND currency::text ~ '^[A-Z]{3}$'::text", name: "crm_opportunities_currency_format"
    t.check_constraint "length(btrim(name::text)) > 0", name: "crm_opportunities_name_present"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying, 'won'::character varying, 'lost'::character varying]::text[])", name: "crm_opportunities_status_allowed"
  end

  create_table "crm_pipeline_stages", force: :cascade do |t|
    t.boolean "closed_lost", default: false, null: false
    t.boolean "closed_won", default: false, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.bigint "pipeline_id", null: false
    t.integer "position", default: 0, null: false
    t.integer "probability", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "pipeline_id"], name: "index_crm_pipeline_stages_on_organization_id_and_pipeline_id"
    t.index ["organization_id"], name: "index_crm_pipeline_stages_on_organization_id"
    t.index ["pipeline_id", "position"], name: "index_crm_pipeline_stages_on_pipeline_id_and_position"
    t.index ["pipeline_id"], name: "index_crm_pipeline_stages_on_pipeline_id"
    t.check_constraint "NOT (closed_won AND closed_lost)", name: "crm_pipeline_stages_not_both_closed"
    t.check_constraint "\"position\" >= 0", name: "crm_pipeline_stages_position_nonnegative"
    t.check_constraint "length(btrim(name::text)) > 0", name: "crm_pipeline_stages_name_present"
    t.check_constraint "probability >= 0 AND probability <= 100", name: "crm_pipeline_stages_probability_range"
  end

  create_table "crm_pipelines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "name"], name: "index_crm_pipelines_on_organization_id_and_name", unique: true
    t.index ["organization_id", "position"], name: "index_crm_pipelines_on_organization_id_and_position"
    t.index ["organization_id"], name: "index_crm_pipelines_on_organization_id"
    t.check_constraint "\"position\" >= 0", name: "crm_pipelines_position_nonnegative"
    t.check_constraint "length(btrim(name::text)) > 0", name: "crm_pipelines_name_present"
  end

  create_table "crm_taggings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "organization_id", null: false
    t.bigint "tag_id", null: false
    t.bigint "taggable_id", null: false
    t.string "taggable_type", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "taggable_type", "taggable_id"], name: "index_crm_taggings_on_org_taggable"
    t.index ["organization_id"], name: "index_crm_taggings_on_organization_id"
    t.index ["tag_id", "taggable_type", "taggable_id"], name: "index_crm_taggings_uniqueness", unique: true
    t.index ["tag_id"], name: "index_crm_taggings_on_tag_id"
    t.check_constraint "taggable_type::text = ANY (ARRAY['Foundation::Crm::Contact'::character varying, 'Foundation::Crm::Company'::character varying, 'Foundation::Crm::Lead'::character varying, 'Foundation::Crm::Opportunity'::character varying]::text[])", name: "crm_taggings_taggable_type_allowed"
  end

  create_table "crm_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "name"], name: "index_crm_tags_on_organization_id_and_name", unique: true
    t.index ["organization_id"], name: "index_crm_tags_on_organization_id"
    t.check_constraint "length(btrim(name::text)) > 0", name: "crm_tags_name_present"
  end

  create_table "crm_tasks", force: :cascade do |t|
    t.bigint "assignee_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.text "description", default: "", null: false
    t.date "due_on"
    t.bigint "organization_id", null: false
    t.string "status", default: "open", null: false
    t.bigint "taskable_id"
    t.string "taskable_type"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id"], name: "index_crm_tasks_on_assignee_id"
    t.index ["creator_id"], name: "index_crm_tasks_on_creator_id"
    t.index ["organization_id", "assignee_id"], name: "index_crm_tasks_on_organization_id_and_assignee_id"
    t.index ["organization_id", "status", "due_on"], name: "index_crm_tasks_on_organization_id_and_status_and_due_on"
    t.index ["organization_id", "taskable_type", "taskable_id"], name: "index_crm_tasks_on_org_taskable"
    t.index ["organization_id"], name: "index_crm_tasks_on_organization_id"
    t.check_constraint "length(btrim(title::text)) > 0", name: "crm_tasks_title_present"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying, 'done'::character varying, 'canceled'::character varying]::text[])", name: "crm_tasks_status_allowed"
    t.check_constraint "taskable_type IS NULL OR (taskable_type::text = ANY (ARRAY['Foundation::Crm::Contact'::character varying, 'Foundation::Crm::Company'::character varying, 'Foundation::Crm::Lead'::character varying, 'Foundation::Crm::Opportunity'::character varying]::text[]))", name: "crm_tasks_taskable_type_allowed"
  end

  create_table "identities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["provider", "uid"], name: "index_identities_on_provider_and_uid", unique: true
    t.index ["user_id"], name: "index_identities_on_user_id"
  end

  create_table "legal_acceptances", force: :cascade do |t|
    t.datetime "accepted_at", null: false
    t.string "context", default: "signup", null: false
    t.datetime "created_at", null: false
    t.string "ip"
    t.string "privacy_version", null: false
    t.string "terms_version", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_legal_acceptances_on_user_id"
  end

  create_table "nondisposable_disposable_domains", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_nondisposable_disposable_domains_on_name", unique: true
  end

  create_table "organizations_allowlist_entries", force: :cascade do |t|
    t.datetime "claimed_at"
    t.bigint "claimed_by_id"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "email_normalized", null: false
    t.jsonb "membership_metadata", default: {}, null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "organization_id", null: false
    t.string "source"
    t.datetime "updated_at", null: false
    t.index ["claimed_by_id"], name: "index_organizations_allowlist_entries_on_claimed_by_id"
    t.index ["organization_id", "email_normalized"], name: "idx_on_organization_id_email_normalized_479be2d31c", unique: true
    t.index ["organization_id"], name: "index_organizations_allowlist_entries_on_organization_id"
  end

  create_table "organizations_domains", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "domain", null: false
    t.jsonb "membership_metadata", default: {}, null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["domain"], name: "index_organizations_domains_on_domain"
    t.index ["organization_id", "domain"], name: "index_organizations_domains_on_organization_id_and_domain", unique: true
    t.index ["organization_id"], name: "index_organizations_domains_on_organization_id"
  end

  create_table "organizations_invitations", force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "expires_at"
    t.bigint "invited_by_id"
    t.jsonb "membership_metadata", default: {}, null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "organization_id", null: false
    t.string "role", default: "member", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index "organization_id, lower((email)::text)", name: "index_organizations_invitations_pending_unique", unique: true, where: "(accepted_at IS NULL)"
    t.index ["email"], name: "index_organizations_invitations_on_email"
    t.index ["invited_by_id"], name: "index_organizations_invitations_on_invited_by_id"
    t.index ["organization_id"], name: "index_organizations_invitations_on_organization_id"
    t.index ["token"], name: "index_organizations_invitations_on_token", unique: true
  end

  create_table "organizations_join_codes", force: :cascade do |t|
    t.boolean "auto_approve", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.datetime "expires_at"
    t.string "label"
    t.integer "max_uses"
    t.jsonb "membership_metadata", default: {}, null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "organization_id", null: false
    t.boolean "requires_verified_domain_email", default: false, null: false
    t.datetime "revoked_at"
    t.datetime "updated_at", null: false
    t.integer "uses_count", default: 0, null: false
    t.index ["code"], name: "index_organizations_join_codes_on_code", unique: true
    t.index ["created_by_id"], name: "index_organizations_join_codes_on_created_by_id"
    t.index ["organization_id"], name: "index_organizations_join_codes_on_organization_id"
  end

  create_table "organizations_join_requests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "decided_at"
    t.bigint "decided_by_id"
    t.datetime "expires_at"
    t.bigint "join_code_id"
    t.string "joined_via"
    t.string "message"
    t.jsonb "metadata", default: {}, null: false
    t.bigint "organization_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "verification_attempts", default: 0, null: false
    t.string "verification_code_digest"
    t.string "verification_email"
    t.string "verification_email_normalized"
    t.datetime "verification_expires_at"
    t.integer "verification_sends_count", default: 0, null: false
    t.datetime "verification_sent_at"
    t.datetime "verified_at"
    t.index ["decided_by_id"], name: "index_organizations_join_requests_on_decided_by_id"
    t.index ["join_code_id"], name: "index_organizations_join_requests_on_join_code_id"
    t.index ["organization_id", "user_id"], name: "index_org_join_requests_pending_unique", unique: true, where: "((status)::text = 'pending'::text)"
    t.index ["organization_id"], name: "index_organizations_join_requests_on_organization_id"
    t.index ["status"], name: "index_organizations_join_requests_on_status"
    t.index ["user_id"], name: "index_organizations_join_requests_on_user_id"
  end

  create_table "organizations_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "invited_by_id"
    t.string "joined_via"
    t.jsonb "metadata", default: {}, null: false
    t.bigint "organization_id", null: false
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.datetime "verified_at"
    t.string "verified_email"
    t.string "verified_email_normalized"
    t.index ["invited_by_id"], name: "index_organizations_memberships_on_invited_by_id"
    t.index ["organization_id", "verified_email_normalized"], name: "index_org_memberships_verified_email_unique", unique: true
    t.index ["organization_id"], name: "index_organizations_memberships_on_organization_id"
    t.index ["organization_id"], name: "index_organizations_memberships_single_owner", unique: true, where: "((role)::text = 'owner'::text)"
    t.index ["role"], name: "index_organizations_memberships_on_role"
    t.index ["user_id", "organization_id"], name: "index_organizations_memberships_on_user_id_and_organization_id", unique: true
    t.index ["user_id"], name: "index_organizations_memberships_on_user_id"
  end

  create_table "organizations_organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "memberships_count", default: 0, null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "pay_charges", force: :cascade do |t|
    t.integer "amount", null: false
    t.integer "amount_refunded"
    t.integer "application_fee_amount"
    t.datetime "created_at", null: false
    t.string "currency"
    t.bigint "customer_id", null: false
    t.jsonb "data"
    t.jsonb "metadata"
    t.jsonb "object"
    t.string "processor_id", null: false
    t.string "stripe_account"
    t.bigint "subscription_id"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["customer_id", "processor_id"], name: "index_pay_charges_on_customer_id_and_processor_id", unique: true
    t.index ["subscription_id"], name: "index_pay_charges_on_subscription_id"
  end

  create_table "pay_customers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "data"
    t.boolean "default"
    t.datetime "deleted_at", precision: nil
    t.jsonb "object"
    t.bigint "owner_id"
    t.string "owner_type"
    t.string "processor", null: false
    t.string "processor_id"
    t.string "stripe_account"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id", "deleted_at"], name: "pay_customer_owner_index", unique: true
    t.index ["processor", "processor_id"], name: "index_pay_customers_on_processor_and_processor_id", unique: true
  end

  create_table "pay_merchants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "data"
    t.boolean "default"
    t.bigint "owner_id"
    t.string "owner_type"
    t.string "processor", null: false
    t.string "processor_id"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id", "processor"], name: "index_pay_merchants_on_owner_type_and_owner_id_and_processor"
  end

  create_table "pay_payment_methods", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.jsonb "data"
    t.boolean "default"
    t.string "payment_method_type"
    t.string "processor_id", null: false
    t.string "stripe_account"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["customer_id", "processor_id"], name: "index_pay_payment_methods_on_customer_id_and_processor_id", unique: true
  end

  create_table "pay_subscriptions", force: :cascade do |t|
    t.decimal "application_fee_percent", precision: 8, scale: 2
    t.datetime "created_at", null: false
    t.datetime "current_period_end", precision: nil
    t.datetime "current_period_start", precision: nil
    t.bigint "customer_id", null: false
    t.jsonb "data"
    t.datetime "ends_at", precision: nil
    t.jsonb "metadata"
    t.boolean "metered"
    t.string "name", null: false
    t.jsonb "object"
    t.string "pause_behavior"
    t.datetime "pause_resumes_at", precision: nil
    t.datetime "pause_starts_at", precision: nil
    t.string "payment_method_id"
    t.string "processor_id", null: false
    t.string "processor_plan", null: false
    t.integer "quantity", default: 1, null: false
    t.string "status", null: false
    t.string "stripe_account"
    t.datetime "trial_ends_at", precision: nil
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["customer_id", "processor_id"], name: "index_pay_subscriptions_on_customer_id_and_processor_id", unique: true
    t.index ["metered"], name: "index_pay_subscriptions_on_metered"
    t.index ["pause_starts_at"], name: "index_pay_subscriptions_on_pause_starts_at"
  end

  create_table "pay_webhooks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "event"
    t.string "event_type"
    t.string "processor"
    t.datetime "updated_at", null: false
  end

  create_table "pricing_plans_assignments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "plan_key", null: false
    t.bigint "plan_owner_id", null: false
    t.string "plan_owner_type", null: false
    t.string "source", default: "manual", null: false
    t.datetime "updated_at", null: false
    t.index ["plan_key"], name: "idx_pricing_plans_assignments_plan"
    t.index ["plan_owner_type", "plan_owner_id"], name: "idx_pricing_plans_assignments_unique", unique: true
    t.index ["plan_owner_type", "plan_owner_id"], name: "index_pricing_plans_assignments_on_plan_owner"
  end

  create_table "pricing_plans_enforcement_states", force: :cascade do |t|
    t.datetime "blocked_at"
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}
    t.datetime "exceeded_at"
    t.datetime "last_warning_at"
    t.decimal "last_warning_threshold", precision: 3, scale: 2
    t.string "limit_key", null: false
    t.bigint "plan_owner_id", null: false
    t.string "plan_owner_type", null: false
    t.datetime "updated_at", null: false
    t.index ["exceeded_at"], name: "idx_pricing_plans_enforcement_exceeded", where: "(exceeded_at IS NOT NULL)"
    t.index ["plan_owner_type", "plan_owner_id", "limit_key"], name: "idx_pricing_plans_enforcement_unique", unique: true
    t.index ["plan_owner_type", "plan_owner_id"], name: "idx_pricing_plans_enforcement_plan_owner"
    t.index ["plan_owner_type", "plan_owner_id"], name: "index_pricing_plans_enforcement_states_on_plan_owner"
  end

  create_table "pricing_plans_usages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_used_at"
    t.string "limit_key", null: false
    t.datetime "period_end", null: false
    t.datetime "period_start", null: false
    t.bigint "plan_owner_id", null: false
    t.string "plan_owner_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "used", default: 0, null: false
    t.index ["period_start", "period_end"], name: "idx_pricing_plans_usages_period"
    t.index ["plan_owner_type", "plan_owner_id", "limit_key", "period_start"], name: "idx_pricing_plans_usages_unique", unique: true
    t.index ["plan_owner_type", "plan_owner_id"], name: "idx_pricing_plans_usages_plan_owner"
    t.index ["plan_owner_type", "plan_owner_id"], name: "index_pricing_plans_usages_on_plan_owner"
  end

  create_table "reauthentication_attempts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key_digest", null: false
    t.string "kind", null: false
    t.index ["created_at"], name: "index_reauthentication_attempts_on_created_at"
    t.index ["kind", "key_digest", "created_at"], name: "index_reauthentication_attempts_lookup"
    t.check_constraint "kind::text = ANY (ARRAY['account'::character varying, 'ip'::character varying]::text[])", name: "reauthentication_attempts_kind_allowed"
  end

  create_table "sessions", force: :cascade do |t|
    t.string "adoption_key"
    t.string "app_build"
    t.string "app_name"
    t.string "app_version"
    t.jsonb "auth_detail"
    t.string "auth_method"
    t.string "auth_provider"
    t.string "browser_name"
    t.string "browser_version"
    t.string "city"
    t.jsonb "client_hints"
    t.string "country_code", limit: 2
    t.string "country_name"
    t.datetime "created_at", null: false
    t.string "device_id", limit: 36
    t.string "device_model"
    t.string "device_type"
    t.datetime "ended_at"
    t.bigint "ended_by_id"
    t.string "ended_by_type"
    t.jsonb "ended_metadata"
    t.string "ended_reason"
    t.string "ip_address", limit: 45
    t.datetime "last_seen_at"
    t.string "last_seen_ip", limit: 45
    t.string "os_name"
    t.string "os_version"
    t.string "region"
    t.string "scope"
    t.string "token_digest"
    t.datetime "updated_at", null: false
    t.text "user_agent"
    t.bigint "user_id", null: false
    t.index ["adoption_key"], name: "index_sessions_on_adoption_key", unique: true
    t.index ["auth_method"], name: "index_sessions_on_auth_method"
    t.index ["auth_provider"], name: "index_sessions_on_auth_provider"
    t.index ["country_code"], name: "index_sessions_on_country_code"
    t.index ["device_id"], name: "index_sessions_on_device_id"
    t.index ["ended_at"], name: "index_sessions_on_ended_at"
    t.index ["ended_by_type", "ended_by_id"], name: "index_sessions_on_ended_by_type_and_ended_by_id"
    t.index ["ended_reason"], name: "index_sessions_on_ended_reason"
    t.index ["last_seen_at"], name: "index_sessions_on_last_seen_at"
    t.index ["token_digest"], name: "index_sessions_on_token_digest", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "sessions_events", force: :cascade do |t|
    t.string "app_build"
    t.string "app_name"
    t.string "app_version"
    t.jsonb "auth_detail"
    t.string "auth_method"
    t.string "auth_provider"
    t.bigint "authenticatable_id"
    t.string "authenticatable_type"
    t.string "browser_name"
    t.string "browser_version"
    t.string "city"
    t.jsonb "client_hints"
    t.string "context"
    t.string "country_code", limit: 2
    t.string "country_name"
    t.string "device_id", limit: 36
    t.string "device_model"
    t.string "device_type"
    t.string "event", null: false
    t.string "failure_reason"
    t.string "identity"
    t.string "ip_address", limit: 45
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.jsonb "metadata"
    t.datetime "occurred_at", null: false
    t.string "os_name"
    t.string "os_version"
    t.string "region"
    t.string "request_id"
    t.string "revoked_reason"
    t.string "scope"
    t.bigint "session_id"
    t.text "user_agent"
    t.index ["authenticatable_type", "authenticatable_id", "occurred_at"], name: "index_sessions_events_on_authenticatable_and_occurred_at"
    t.index ["device_id", "occurred_at"], name: "index_sessions_events_on_device_id_and_occurred_at"
    t.index ["event", "occurred_at"], name: "index_sessions_events_on_event_and_occurred_at"
    t.index ["identity"], name: "index_sessions_events_on_identity"
    t.index ["ip_address"], name: "index_sessions_events_on_ip_address"
    t.index ["occurred_at"], name: "index_sessions_events_on_occurred_at"
    t.index ["session_id"], name: "index_sessions_events_on_session_id"
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

  create_table "storefront_checkout_attempts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key_digest", null: false
    t.string "kind", null: false
    t.index ["created_at"], name: "index_storefront_checkout_attempts_on_created_at"
    t.index ["kind", "key_digest", "created_at"], name: "index_storefront_checkout_attempts_lookup"
    t.check_constraint "kind::text = ANY (ARRAY['session'::character varying::text, 'ip'::character varying::text])", name: "storefront_checkout_attempts_kind_allowed"
  end

  create_table "storefront_line_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, null: false
    t.bigint "line_total_cents", null: false
    t.string "name", null: false
    t.bigint "order_id", null: false
    t.bigint "product_id"
    t.integer "quantity", null: false
    t.string "sku", null: false
    t.bigint "unit_price_cents", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id", "product_id"], name: "index_storefront_line_items_on_order_id_and_product_id"
    t.index ["order_id"], name: "index_storefront_line_items_on_order_id"
    t.index ["product_id"], name: "index_storefront_line_items_on_product_id"
    t.check_constraint "currency::text = upper(currency::text) AND currency::text ~ '^[A-Z]{3}$'::text", name: "storefront_line_items_currency_format"
    t.check_constraint "length(btrim(name::text)) > 0 AND length(btrim(sku::text)) > 0", name: "storefront_line_items_snapshot_present"
    t.check_constraint "line_total_cents = (unit_price_cents * quantity)", name: "storefront_line_items_total_matches"
    t.check_constraint "quantity >= 1 AND quantity <= 10", name: "storefront_line_items_quantity_range"
    t.check_constraint "unit_price_cents >= 0 AND line_total_cents >= 0", name: "storefront_line_items_prices_nonnegative"
  end

  create_table "storefront_orders", force: :cascade do |t|
    t.string "acceptance_ip"
    t.string "acceptance_user_agent"
    t.datetime "canceled_at"
    t.string "checkout_key_digest", null: false
    t.datetime "checkout_started_at"
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, null: false
    t.string "email", null: false
    t.datetime "fulfilled_at"
    t.datetime "inventory_released_at"
    t.datetime "legal_accepted_at", null: false
    t.datetime "paid_at"
    t.string "privacy_version", null: false
    t.string "provider_payment_id"
    t.string "public_reference", null: false
    t.datetime "receipt_queued_at"
    t.datetime "receipt_sent_at"
    t.datetime "refunded_at"
    t.datetime "reservation_expires_at", null: false
    t.boolean "simulated", default: false, null: false
    t.string "state", default: "pending", null: false
    t.string "stripe_session_id"
    t.bigint "subtotal_cents", null: false
    t.string "terms_version", null: false
    t.bigint "total_cents", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["checkout_key_digest"], name: "index_storefront_orders_on_checkout_key_digest", unique: true
    t.index ["provider_payment_id"], name: "index_storefront_orders_on_provider_payment_id", unique: true, where: "(provider_payment_id IS NOT NULL)"
    t.index ["public_reference"], name: "index_storefront_orders_on_public_reference", unique: true
    t.index ["state", "created_at"], name: "index_storefront_orders_on_state_and_created_at"
    t.index ["state", "reservation_expires_at"], name: "index_storefront_orders_on_state_and_reservation_expires_at"
    t.index ["stripe_session_id"], name: "index_storefront_orders_on_stripe_session_id", unique: true, where: "(stripe_session_id IS NOT NULL)"
    t.index ["user_id", "created_at"], name: "index_storefront_orders_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_storefront_orders_on_user_id"
    t.check_constraint "currency::text = upper(currency::text) AND currency::text ~ '^[A-Z]{3}$'::text", name: "storefront_orders_currency_format"
    t.check_constraint "length(btrim(email::text)) > 0", name: "storefront_orders_email_present"
    t.check_constraint "state::text = ANY (ARRAY['pending'::character varying::text, 'paid'::character varying::text, 'fulfilled'::character varying::text, 'canceled'::character varying::text, 'refunded'::character varying::text])", name: "storefront_orders_state_allowed"
    t.check_constraint "subtotal_cents = total_cents", name: "storefront_orders_total_matches_subtotal"
    t.check_constraint "subtotal_cents >= 0 AND total_cents >= 0", name: "storefront_orders_totals_nonnegative"
  end

  create_table "storefront_payment_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "error_code"
    t.string "event_type", null: false
    t.bigint "order_id"
    t.string "payload_digest", null: false
    t.datetime "processed_at"
    t.string "provider", null: false
    t.string "provider_event_id", null: false
    t.string "provider_payment_id"
    t.string "provider_session_id"
    t.string "status", default: "received", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_storefront_payment_events_on_order_id"
    t.index ["provider", "provider_event_id"], name: "idx_on_provider_provider_event_id_6a77f7d194", unique: true
    t.index ["provider_payment_id", "created_at"], name: "idx_on_provider_payment_id_created_at_39d3bb7d27"
    t.index ["provider_session_id", "created_at"], name: "idx_on_provider_session_id_created_at_c5965c0dc6"
    t.index ["status", "created_at"], name: "index_storefront_payment_events_on_status_and_created_at"
    t.check_constraint "length(btrim(provider_event_id::text)) > 0", name: "storefront_payment_events_id_present"
    t.check_constraint "status::text = ANY (ARRAY['received'::character varying::text, 'processed'::character varying::text, 'rejected'::character varying::text, 'ignored'::character varying::text])", name: "storefront_payment_events_status_allowed"
  end

  create_table "storefront_products", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "USD", null: false
    t.text "description", default: "", null: false
    t.string "image_url"
    t.integer "inventory_quantity", default: 0, null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.bigint "price_cents", null: false
    t.string "sku", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "position"], name: "index_storefront_products_on_active_and_position"
    t.index ["sku"], name: "index_storefront_products_on_sku", unique: true
    t.index ["slug"], name: "index_storefront_products_on_slug", unique: true
    t.check_constraint "\"position\" <= 1000000", name: "storefront_products_position_bounded"
    t.check_constraint "\"position\" >= 0", name: "storefront_products_position_nonnegative"
    t.check_constraint "currency::text = upper(currency::text) AND currency::text ~ '^[A-Z]{3}$'::text", name: "storefront_products_currency_format"
    t.check_constraint "inventory_quantity <= 1000000", name: "storefront_products_inventory_bounded"
    t.check_constraint "inventory_quantity >= 0", name: "storefront_products_inventory_nonnegative"
    t.check_constraint "length(btrim(name::text)) > 0", name: "storefront_products_name_present"
    t.check_constraint "length(btrim(sku::text)) > 0", name: "storefront_products_sku_present"
    t.check_constraint "length(btrim(slug::text)) > 0", name: "storefront_products_slug_present"
    t.check_constraint "price_cents <= 999999999", name: "storefront_products_price_bounded"
    t.check_constraint "price_cents >= 0", name: "storefront_products_price_nonnegative"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "locked_at"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "unconfirmed_email"
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "crm_activities", "organizations_organizations", column: "organization_id", on_delete: :cascade
  add_foreign_key "crm_activities", "users", column: "actor_id", on_delete: :nullify
  add_foreign_key "crm_companies", "organizations_organizations", column: "organization_id", on_delete: :cascade
  add_foreign_key "crm_contacts", "crm_companies", column: "company_id", on_delete: :nullify
  add_foreign_key "crm_contacts", "organizations_organizations", column: "organization_id", on_delete: :cascade
  add_foreign_key "crm_contacts", "users", column: "owner_id", on_delete: :nullify
  add_foreign_key "crm_leads", "crm_companies", column: "company_id", on_delete: :nullify
  add_foreign_key "crm_leads", "crm_contacts", column: "contact_id", on_delete: :nullify
  add_foreign_key "crm_leads", "organizations_organizations", column: "organization_id", on_delete: :cascade
  add_foreign_key "crm_leads", "users", column: "owner_id", on_delete: :nullify
  add_foreign_key "crm_notes", "organizations_organizations", column: "organization_id", on_delete: :cascade
  add_foreign_key "crm_notes", "users", column: "author_id", on_delete: :restrict
  add_foreign_key "crm_opportunities", "crm_companies", column: "company_id", on_delete: :nullify
  add_foreign_key "crm_opportunities", "crm_contacts", column: "contact_id", on_delete: :nullify
  add_foreign_key "crm_opportunities", "crm_pipeline_stages", column: "pipeline_stage_id", on_delete: :restrict
  add_foreign_key "crm_opportunities", "crm_pipelines", column: "pipeline_id", on_delete: :restrict
  add_foreign_key "crm_opportunities", "organizations_organizations", column: "organization_id", on_delete: :cascade
  add_foreign_key "crm_opportunities", "users", column: "owner_id", on_delete: :nullify
  add_foreign_key "crm_pipeline_stages", "crm_pipelines", column: "pipeline_id", on_delete: :cascade
  add_foreign_key "crm_pipeline_stages", "organizations_organizations", column: "organization_id", on_delete: :cascade
  add_foreign_key "crm_pipelines", "organizations_organizations", column: "organization_id", on_delete: :cascade
  add_foreign_key "crm_taggings", "crm_tags", column: "tag_id", on_delete: :cascade
  add_foreign_key "crm_taggings", "organizations_organizations", column: "organization_id", on_delete: :cascade
  add_foreign_key "crm_tags", "organizations_organizations", column: "organization_id", on_delete: :cascade
  add_foreign_key "crm_tasks", "organizations_organizations", column: "organization_id", on_delete: :cascade
  add_foreign_key "crm_tasks", "users", column: "assignee_id", on_delete: :nullify
  add_foreign_key "crm_tasks", "users", column: "creator_id", on_delete: :restrict
  add_foreign_key "identities", "users"
  add_foreign_key "legal_acceptances", "users"
  add_foreign_key "organizations_allowlist_entries", "organizations_organizations", column: "organization_id"
  add_foreign_key "organizations_allowlist_entries", "users", column: "claimed_by_id"
  add_foreign_key "organizations_domains", "organizations_organizations", column: "organization_id"
  add_foreign_key "organizations_invitations", "organizations_organizations", column: "organization_id"
  add_foreign_key "organizations_invitations", "users", column: "invited_by_id"
  add_foreign_key "organizations_join_codes", "organizations_organizations", column: "organization_id"
  add_foreign_key "organizations_join_codes", "users", column: "created_by_id"
  add_foreign_key "organizations_join_requests", "organizations_join_codes", column: "join_code_id"
  add_foreign_key "organizations_join_requests", "organizations_organizations", column: "organization_id"
  add_foreign_key "organizations_join_requests", "users"
  add_foreign_key "organizations_join_requests", "users", column: "decided_by_id"
  add_foreign_key "organizations_memberships", "organizations_organizations", column: "organization_id"
  add_foreign_key "organizations_memberships", "users"
  add_foreign_key "organizations_memberships", "users", column: "invited_by_id"
  add_foreign_key "pay_charges", "pay_customers", column: "customer_id"
  add_foreign_key "pay_charges", "pay_subscriptions", column: "subscription_id"
  add_foreign_key "pay_payment_methods", "pay_customers", column: "customer_id"
  add_foreign_key "pay_subscriptions", "pay_customers", column: "customer_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "storefront_line_items", "storefront_orders", column: "order_id", on_delete: :cascade
  add_foreign_key "storefront_line_items", "storefront_products", column: "product_id", on_delete: :nullify
  add_foreign_key "storefront_orders", "users", on_delete: :nullify
  add_foreign_key "storefront_payment_events", "storefront_orders", column: "order_id", on_delete: :nullify
end
