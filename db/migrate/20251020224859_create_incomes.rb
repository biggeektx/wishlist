class CreateIncomes < ActiveRecord::Migration[8.0]
  def change
    create_table :incomes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :description, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :frequency, null: false
      t.integer :frequency_day
      t.date :start_date

      t.timestamps
    end

    add_index :incomes, [:user_id, :frequency]
  end
end
