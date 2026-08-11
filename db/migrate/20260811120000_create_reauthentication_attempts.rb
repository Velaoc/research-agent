# frozen_string_literal: true

class CreateReauthenticationAttempts < ActiveRecord::Migration[8.1]
  def change
    create_table :reauthentication_attempts do |t|
      t.string :key_digest, null: false
      t.string :kind, null: false
      t.datetime :created_at, null: false

      t.index %i[kind key_digest created_at], name: "index_reauthentication_attempts_lookup"
      t.index :created_at
      t.check_constraint "kind IN ('account','ip')", name: "reauthentication_attempts_kind_allowed"
    end
  end
end
