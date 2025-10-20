class CreateWishListItems < ActiveRecord::Migration[8.0]
  def change
    create_table :wish_list_items do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :cost, precision: 10, scale: 2, null: false
      t.string :item_type, null: false
      t.date :target_date
      t.integer :sequential_order
      t.decimal :percentage, precision: 5, scale: 2
      t.boolean :purchased, default: false
      t.datetime :purchased_at

      t.timestamps
    end

    add_index :wish_list_items, [:user_id, :item_type]
    add_index :wish_list_items, [:user_id, :purchased]
  end
end
