# frozen_string_literal: true

class CreateCrm < ActiveRecord::Migration[8.1]
  def change
    create_table :crm_companies do |t|
      t.references :organization, null: false, foreign_key: { to_table: :organizations_organizations, on_delete: :cascade }
      t.string :name, null: false
      t.string :domain
      t.string :website
      t.string :phone
      t.string :industry
      t.timestamps

      t.index %i[organization_id name]
      t.index %i[organization_id domain], unique: true, where: "domain IS NOT NULL AND length(btrim(domain)) > 0", name: "index_crm_companies_on_org_domain"
      t.check_constraint "length(btrim(name)) > 0", name: "crm_companies_name_present"
    end

    create_table :crm_contacts do |t|
      t.references :organization, null: false, foreign_key: { to_table: :organizations_organizations, on_delete: :cascade }
      t.references :company, foreign_key: { to_table: :crm_companies, on_delete: :nullify }
      t.references :owner, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :first_name, null: false, default: ""
      t.string :last_name, null: false, default: ""
      t.string :email
      t.string :phone
      t.string :title
      t.timestamps

      t.index %i[organization_id last_name first_name]
      t.index %i[organization_id email], where: "email IS NOT NULL"
      t.index %i[organization_id owner_id]
      t.check_constraint "length(btrim(first_name)) > 0 OR length(btrim(last_name)) > 0 OR length(btrim(coalesce(email, ''))) > 0", name: "crm_contacts_identity_present"
    end

    create_table :crm_pipelines do |t|
      t.references :organization, null: false, foreign_key: { to_table: :organizations_organizations, on_delete: :cascade }
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps

      t.index %i[organization_id position]
      t.index %i[organization_id name], unique: true
      t.check_constraint "length(btrim(name)) > 0", name: "crm_pipelines_name_present"
      t.check_constraint "position >= 0", name: "crm_pipelines_position_nonnegative"
    end

    create_table :crm_pipeline_stages do |t|
      t.references :organization, null: false, foreign_key: { to_table: :organizations_organizations, on_delete: :cascade }
      t.references :pipeline, null: false, foreign_key: { to_table: :crm_pipelines, on_delete: :cascade }
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.integer :probability, null: false, default: 0
      t.boolean :closed_won, null: false, default: false
      t.boolean :closed_lost, null: false, default: false
      t.timestamps

      t.index %i[pipeline_id position]
      t.index %i[organization_id pipeline_id]
      t.check_constraint "length(btrim(name)) > 0", name: "crm_pipeline_stages_name_present"
      t.check_constraint "position >= 0", name: "crm_pipeline_stages_position_nonnegative"
      t.check_constraint "probability >= 0 AND probability <= 100", name: "crm_pipeline_stages_probability_range"
      t.check_constraint "NOT (closed_won AND closed_lost)", name: "crm_pipeline_stages_not_both_closed"
    end

    create_table :crm_leads do |t|
      t.references :organization, null: false, foreign_key: { to_table: :organizations_organizations, on_delete: :cascade }
      t.references :company, foreign_key: { to_table: :crm_companies, on_delete: :nullify }
      t.references :contact, foreign_key: { to_table: :crm_contacts, on_delete: :nullify }
      t.references :owner, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :name, null: false
      t.string :email
      t.string :phone
      t.string :source
      t.string :status, null: false, default: "new"
      t.text :description, null: false, default: ""
      t.timestamps

      t.index %i[organization_id status]
      t.index %i[organization_id owner_id]
      t.index %i[organization_id created_at]
      t.check_constraint "length(btrim(name)) > 0", name: "crm_leads_name_present"
      t.check_constraint "status IN ('new','contacted','qualified','disqualified','converted')", name: "crm_leads_status_allowed"
    end

    create_table :crm_opportunities do |t|
      t.references :organization, null: false, foreign_key: { to_table: :organizations_organizations, on_delete: :cascade }
      t.references :pipeline, null: false, foreign_key: { to_table: :crm_pipelines, on_delete: :restrict }
      t.references :pipeline_stage, null: false, foreign_key: { to_table: :crm_pipeline_stages, on_delete: :restrict }
      t.references :company, foreign_key: { to_table: :crm_companies, on_delete: :nullify }
      t.references :contact, foreign_key: { to_table: :crm_contacts, on_delete: :nullify }
      t.references :owner, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :name, null: false
      t.bigint :amount_cents, null: false, default: 0
      t.string :currency, limit: 3, null: false, default: "USD"
      t.date :expected_close_on
      t.string :status, null: false, default: "open"
      t.text :description, null: false, default: ""
      t.timestamps

      t.index %i[organization_id status]
      t.index %i[organization_id pipeline_stage_id]
      t.index %i[organization_id owner_id]
      t.index %i[organization_id expected_close_on]
      t.check_constraint "length(btrim(name)) > 0", name: "crm_opportunities_name_present"
      t.check_constraint "amount_cents >= 0", name: "crm_opportunities_amount_nonnegative"
      t.check_constraint "currency = upper(currency) AND currency ~ '^[A-Z]{3}$'", name: "crm_opportunities_currency_format"
      t.check_constraint "status IN ('open','won','lost')", name: "crm_opportunities_status_allowed"
    end

    create_table :crm_notes do |t|
      t.references :organization, null: false, foreign_key: { to_table: :organizations_organizations, on_delete: :cascade }
      t.references :author, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :notable_type, null: false
      t.bigint :notable_id, null: false
      t.text :body, null: false
      t.timestamps

      t.index %i[organization_id notable_type notable_id created_at], name: "index_crm_notes_on_org_notable"
      t.check_constraint "length(btrim(body)) > 0", name: "crm_notes_body_present"
      t.check_constraint "notable_type IN ('Foundation::Crm::Contact','Foundation::Crm::Company','Foundation::Crm::Lead','Foundation::Crm::Opportunity')", name: "crm_notes_notable_type_allowed"
    end

    create_table :crm_tasks do |t|
      t.references :organization, null: false, foreign_key: { to_table: :organizations_organizations, on_delete: :cascade }
      t.references :creator, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.references :assignee, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :taskable_type
      t.bigint :taskable_id
      t.string :title, null: false
      t.text :description, null: false, default: ""
      t.date :due_on
      t.string :status, null: false, default: "open"
      t.datetime :completed_at
      t.timestamps

      t.index %i[organization_id status due_on]
      t.index %i[organization_id assignee_id]
      t.index %i[organization_id taskable_type taskable_id], name: "index_crm_tasks_on_org_taskable"
      t.check_constraint "length(btrim(title)) > 0", name: "crm_tasks_title_present"
      t.check_constraint "status IN ('open','done','canceled')", name: "crm_tasks_status_allowed"
      t.check_constraint "taskable_type IS NULL OR taskable_type IN ('Foundation::Crm::Contact','Foundation::Crm::Company','Foundation::Crm::Lead','Foundation::Crm::Opportunity')", name: "crm_tasks_taskable_type_allowed"
    end

    create_table :crm_activities do |t|
      t.references :organization, null: false, foreign_key: { to_table: :organizations_organizations, on_delete: :cascade }
      t.references :actor, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :trackable_type, null: false
      t.bigint :trackable_id, null: false
      t.string :kind, null: false
      t.string :summary, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps

      t.index %i[organization_id trackable_type trackable_id created_at], name: "index_crm_activities_on_org_trackable"
      t.index %i[organization_id created_at]
      t.check_constraint "length(btrim(kind)) > 0", name: "crm_activities_kind_present"
      t.check_constraint "length(btrim(summary)) > 0", name: "crm_activities_summary_present"
      t.check_constraint "trackable_type IN ('Foundation::Crm::Contact','Foundation::Crm::Company','Foundation::Crm::Lead','Foundation::Crm::Opportunity','Foundation::Crm::Task')", name: "crm_activities_trackable_type_allowed"
    end

    create_table :crm_tags do |t|
      t.references :organization, null: false, foreign_key: { to_table: :organizations_organizations, on_delete: :cascade }
      t.string :name, null: false
      t.timestamps

      t.index %i[organization_id name], unique: true
      t.check_constraint "length(btrim(name)) > 0", name: "crm_tags_name_present"
    end

    create_table :crm_taggings do |t|
      t.references :organization, null: false, foreign_key: { to_table: :organizations_organizations, on_delete: :cascade }
      t.references :tag, null: false, foreign_key: { to_table: :crm_tags, on_delete: :cascade }
      t.string :taggable_type, null: false
      t.bigint :taggable_id, null: false
      t.timestamps

      t.index %i[tag_id taggable_type taggable_id], unique: true, name: "index_crm_taggings_uniqueness"
      t.index %i[organization_id taggable_type taggable_id], name: "index_crm_taggings_on_org_taggable"
      t.check_constraint "taggable_type IN ('Foundation::Crm::Contact','Foundation::Crm::Company','Foundation::Crm::Lead','Foundation::Crm::Opportunity')", name: "crm_taggings_taggable_type_allowed"
    end
  end
end
