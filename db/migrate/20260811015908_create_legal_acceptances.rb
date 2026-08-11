class CreateLegalAcceptances < ActiveRecord::Migration[8.1]
  def change
    create_table :legal_acceptances do |t|
      t.references :user, null: false, foreign_key: true
      t.string :terms_version, null: false
      t.string :privacy_version, null: false
      t.datetime :accepted_at, null: false
      t.string :ip
      t.string :user_agent
      t.string :context, null: false, default: "signup"

      t.timestamps
    end
  end
end
