class CreatePurchases < ActiveRecord::Migration[8.0]
  def change
    create_table :purchases do |t|
      t.references :user, null: false, foreign_key: true
      t.references :wish_list_item, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.datetime :purchased_at, null: false
      t.text :notes

      t.timestamps
    end

    add_index :purchases, [:user_id, :purchased_at]
  end
end
