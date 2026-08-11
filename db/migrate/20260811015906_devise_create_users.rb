# Accounts table for Devise (SPEC M2.1). Columns are grouped by concern:
# credentials, brute-force lockout, email confirmation, then recovery and
# remember-me. Token columns are unique-indexed because Devise looks records
# up by them.
class DeviseCreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      # Sign-in credentials
      t.string :email, null: false, default: "", index: { unique: true }
      t.string :encrypted_password, null: false, default: ""

      # Lockout after repeated failures (:lockable)
      t.integer :failed_attempts, null: false, default: 0
      t.string :unlock_token, index: { unique: true }
      t.datetime :locked_at

      # Email confirmation, including re-confirmation of address changes (:confirmable)
      t.string :confirmation_token, index: { unique: true }
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string :unconfirmed_email

      # Password reset (:recoverable) and persistent sessions (:rememberable)
      t.string :reset_password_token, index: { unique: true }
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at

      t.timestamps
    end
  end
end
