class CreateResearchRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :research_runs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :question, null: false
      t.string :status, null: false, default: "queued"
      t.text :summary
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    add_index :research_runs, %i[user_id created_at]
  end
end
