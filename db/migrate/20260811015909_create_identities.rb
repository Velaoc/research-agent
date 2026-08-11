class CreateIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :identities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :uid, null: false

      t.timestamps
    end

    # One external account maps to at most one local user (SPEC M3.2).
    add_index :identities, [ :provider, :uid ], unique: true
  end
end
