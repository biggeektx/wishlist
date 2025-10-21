class AddOneTimeDateToIncomes < ActiveRecord::Migration[8.0]
  def change
    add_column :incomes, :one_time_date, :date
  end
end
