class CreateResearchSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :research_steps do |t|
      t.references :research_run, null: false, foreign_key: true
      t.string :name, null: false
      t.string :status, null: false, default: "pending"
      t.text :input
      t.text :output
      t.integer :position, null: false, default: 0
      t.bigint :duration_ms
      t.timestamps
    end

    add_index :research_steps, %i[research_run_id position]
  end
end
