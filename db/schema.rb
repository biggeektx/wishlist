# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_10_20_225321) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "expenses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "description", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.date "expense_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "expense_date"], name: "index_expenses_on_user_id_and_expense_date"
    t.index ["user_id"], name: "index_expenses_on_user_id"
  end

  create_table "incomes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "description", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "frequency", null: false
    t.integer "frequency_day"
    t.date "start_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "frequency"], name: "index_incomes_on_user_id_and_frequency"
    t.index ["user_id"], name: "index_incomes_on_user_id"
  end

  create_table "purchases", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "wish_list_item_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.datetime "purchased_at", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "purchased_at"], name: "index_purchases_on_user_id_and_purchased_at"
    t.index ["user_id"], name: "index_purchases_on_user_id"
    t.index ["wish_list_item_id"], name: "index_purchases_on_wish_list_item_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "wish_list_items", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.decimal "cost", precision: 10, scale: 2, null: false
    t.string "item_type", null: false
    t.date "target_date"
    t.integer "sequential_order"
    t.decimal "percentage", precision: 5, scale: 2
    t.boolean "purchased", default: false
    t.datetime "purchased_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "item_type"], name: "index_wish_list_items_on_user_id_and_item_type"
    t.index ["user_id", "purchased"], name: "index_wish_list_items_on_user_id_and_purchased"
    t.index ["user_id"], name: "index_wish_list_items_on_user_id"
  end

  add_foreign_key "expenses", "users"
  add_foreign_key "incomes", "users"
  add_foreign_key "purchases", "users"
  add_foreign_key "purchases", "wish_list_items"
  add_foreign_key "wish_list_items", "users"
end
