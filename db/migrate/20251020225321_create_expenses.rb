class CreateExpenses < ActiveRecord::Migration[8.0]
  def change
    create_table :expenses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :description, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.date :expense_date, null: false

      t.timestamps
    end

    add_index :expenses, [:user_id, :expense_date]
  end
end
