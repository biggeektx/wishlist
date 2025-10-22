namespace :debug do
  desc "Debug negative balance issue for specific user"
  task balance: :environment do
    user = User.find_by(email: 'nchewning@gmail.com')

    unless user
      puts "User not found"
      exit
    end

    puts "\n=== USER: #{user.email} ===\n"

    # Get all income
    puts "\n--- INCOME ---"
    calculator = AllocationCalculator.new(user, 2.years.from_now.to_date)
    income_schedule = calculator.send(:build_income_schedule)

    income_schedule.each do |income|
      puts "#{income[:date]}: +$#{income[:amount]} - #{income[:description]}"
    end

    # Get all expenses
    puts "\n--- EXPENSES ---"
    user.expenses.future.order(:expense_date).each do |expense|
      puts "#{expense.expense_date}: -$#{expense.amount} - #{expense.description}"
    end

    # Get wishlist items
    puts "\n--- WISHLIST ITEMS (Unpurchased) ---"
    user.wish_list_items.unpurchased.each do |item|
      puts "#{item.name}: $#{item.cost} (#{item.item_type})"
      if item.item_type == 'target_date'
        puts "  Target Date: #{item.target_date}"
      end
    end

    # Run allocation
    puts "\n--- ALLOCATION RESULTS ---"
    result = calculator.calculate

    result[:allocations].each do |allocation|
      puts "\n#{allocation[:item_name]}:"
      puts "  Cost: $#{allocation[:item_cost]}"
      puts "  Allocated: $#{allocation[:amount_allocated]}"
      puts "  Completion Date: #{allocation[:completion_date]}" if allocation[:completion_date]
      puts "  Feasible: #{allocation[:feasible]}"
      if allocation[:adjusted]
        puts "  ⚠️  ADJUSTED from #{allocation[:original_target]} to #{allocation[:completion_date]}"
      end
    end

    # Build timeline events and calculate balances
    puts "\n--- TIMELINE EVENTS (showing balance calculation) ---"

    all_events = []

    # Add income
    income_schedule.each do |income|
      all_events << {
        type: 'income',
        date: income[:date],
        amount: income[:amount],
        description: income[:description]
      }
    end

    # Add expenses
    user.expenses.future.each do |expense|
      all_events << {
        type: 'expense',
        date: expense.expense_date,
        amount: expense.amount,
        description: expense.description
      }
    end

    # Add wishlist items
    result[:timeline].each do |timeline_item|
      allocation = result[:allocations].find { |a| a[:item_name] == timeline_item[:item].name }
      if allocation && allocation[:completion_date]
        all_events << {
          type: 'wishlist',
          date: allocation[:completion_date],
          amount: timeline_item[:item].cost,
          description: timeline_item[:item].name
        }
      end
    end

    # Sort by date
    all_events.sort_by! { |e| e[:date] }

    # Calculate cumulative balance
    cumulative_balance = 0
    all_events.each do |event|
      case event[:type]
      when 'income'
        cumulative_balance += event[:amount]
        puts "#{event[:date]} | INCOME  | +$#{event[:amount].round(2)} | #{event[:description]} | Balance: $#{cumulative_balance.round(2)}"
      when 'expense'
        cumulative_balance -= event[:amount]
        puts "#{event[:date]} | EXPENSE | -$#{event[:amount].round(2)} | #{event[:description]} | Balance: $#{cumulative_balance.round(2)}"
      when 'wishlist'
        cumulative_balance -= event[:amount]
        puts "#{event[:date]} | WISHLIST| -$#{event[:amount].round(2)} | #{event[:description]} | Balance: $#{cumulative_balance.round(2)}"
      end

      # Highlight negative balances
      if cumulative_balance < 0
        puts "  ⚠️  ⚠️  ⚠️  NEGATIVE BALANCE! ⚠️  ⚠️  ⚠️"
      end
    end

    puts "\n--- SUMMARY ---"
    puts "Total Income: $#{result[:total_income]}"
    puts "Total Expenses: $#{result[:total_expenses]}"
    puts "Total Allocated: $#{result[:allocations].sum { |a| a[:amount_allocated] }}"
    puts "Remaining Funds: $#{result[:remaining_funds]}"
  end
end
