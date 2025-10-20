# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create a demo user
user = User.find_or_create_by!(email: "demo@example.com") do |u|
  u.password = "password"
  u.password_confirmation = "password"
end

puts "Created demo user: #{user.email}"

# Create income sources
income1 = user.incomes.find_or_create_by!(description: "Paycheck (15th of month)") do |i|
  i.amount = 300
  i.frequency = "specific_date"
  i.frequency_day = 15
end

income2 = user.incomes.find_or_create_by!(description: "Paycheck (last day of month)") do |i|
  i.amount = 300
  i.frequency = "last_day"
end

income3 = user.incomes.find_or_create_by!(description: "Biweekly Friday payment") do |i|
  i.amount = 150
  i.frequency = "biweekly"
  i.start_date = Date.current.beginning_of_week + 4.days # Next Friday
end

puts "Created #{user.incomes.count} income sources"

# Create wishlist items - Target Date
desk = user.wish_list_items.find_or_create_by!(name: "Standing Desk") do |w|
  w.cost = 1000
  w.item_type = "target_date"
  w.target_date = Date.new(2026, 3, 31)
end

# Sequential items
desk_chair = user.wish_list_items.find_or_create_by!(name: "Ergonomic Desk Chair") do |w|
  w.cost = 500
  w.item_type = "sequential"
  w.sequential_order = 1
end

desk_mat = user.wish_list_items.find_or_create_by!(name: "Desk Mat") do |w|
  w.cost = 200
  w.item_type = "sequential"
  w.sequential_order = 2
end

# Percentage items
smoker = user.wish_list_items.find_or_create_by!(name: "Pellet Smoker") do |w|
  w.cost = 800
  w.item_type = "percentage"
  w.percentage = 80
end

keyboard = user.wish_list_items.find_or_create_by!(name: "Mechanical Keyboard") do |w|
  w.cost = 200
  w.item_type = "percentage"
  w.percentage = 20
end

puts "Created #{user.wish_list_items.count} wishlist items"

# Create a future expense
expense = user.expenses.find_or_create_by!(description: "Car Insurance") do |e|
  e.amount = 150
  e.expense_date = Date.current + 1.month
end

puts "Created #{user.expenses.count} expense(s)"

puts "\n✅ Seed data created successfully!"
puts "Login with: demo@example.com / password"
