class AllocationCalculator
  attr_reader :user, :end_date, :temp_items, :bumped_sequential, :rebalanced_percentages

  def initialize(user, end_date = 2.years.from_now.to_date, temp_items: [], bumped_sequential: nil, rebalanced_percentages: nil)
    @user = user
    @end_date = end_date
    @temp_items = temp_items
    @bumped_sequential = bumped_sequential
    @rebalanced_percentages = rebalanced_percentages
  end

  def calculate
    # Get all future income
    income_schedule = build_income_schedule

    # Get future expenses
    expense_schedule = build_expense_schedule

    # Get all unpurchased items (including temp items for preview)
    persisted_target = user.wish_list_items.unpurchased.target_date_items.order(:target_date).to_a

    # Use rebalanced percentage items if provided (for preview), otherwise use persisted
    persisted_percentage = if rebalanced_percentages
      rebalanced_percentages
    else
      user.wish_list_items.unpurchased.percentage_items.to_a
    end

    # Use bumped sequential items if provided (for preview), otherwise use persisted
    persisted_sequential = if bumped_sequential
      bumped_sequential
    else
      user.wish_list_items.unpurchased.sequential_items.order(:sequential_order).to_a
    end

    # Add temp items to appropriate collections
    temp_target = temp_items.select { |i| i.item_type == 'target_date' }.sort_by { |i| i.target_date || Date.current + 10.years }
    temp_sequential = temp_items.select { |i| i.item_type == 'sequential' }
    temp_percentage = temp_items.select { |i| i.item_type == 'percentage' }

    target_items = persisted_target + temp_target
    sequential_items = (persisted_sequential + temp_sequential).sort_by { |i| i.sequential_order || 999 }
    percentage_items = persisted_percentage + temp_percentage

    # Initialize result structure
    result = {
      total_income: income_schedule.sum { |i| i[:amount] },
      total_expenses: expense_schedule.sum { |e| e[:amount] },
      allocations: [],
      expenses: expense_schedule,
      incomes: income_schedule,
      timeline: [],
      remaining_funds: 0
    }

    available_funds = income_schedule.dup
    cumulative_total = 0

    # Phase 1: Allocate for target date items
    target_items.each do |item|
      allocation = allocate_for_target_date(item, available_funds.dup)
      if allocation[:feasible]
        result[:allocations] << allocation
        result[:timeline] << {
          item: item,
          funded_by: allocation[:funded_by],
          type: "target_date"
        }
      else
        result[:allocations] << allocation.merge(warning: "Cannot meet target date with current income")
      end
    end

    # Calculate remaining funds after target date items
    remaining_by_date = calculate_remaining_funds(income_schedule, result[:allocations])

    # Phase 2: Allocate for sequential items
    sequential_items.each do |item|
      allocation = allocate_sequential(item, remaining_by_date, result[:allocations])
      result[:allocations] << allocation
      result[:timeline] << {
        item: item,
        funded_by: allocation[:funded_by],
        type: "sequential"
      }
      # Recalculate remaining after each sequential item
      remaining_by_date = calculate_remaining_funds(income_schedule, result[:allocations])
    end

    # Phase 3: Allocate remaining by percentage
    if percentage_items.any?
      total_percentage = percentage_items.sum { |i| i.percentage || 0 }
      percentage_items.each do |item|
        weight = item.percentage / total_percentage
        allocation = allocate_by_percentage(item, remaining_by_date, weight, result[:allocations])
        result[:allocations] << allocation
        result[:timeline] << {
          item: item,
          funded_by: allocation[:funded_by],
          type: "percentage"
        }
        # Recalculate remaining after each percentage item
        remaining_by_date = calculate_remaining_funds(income_schedule, result[:allocations])
      end
    end

    # Calculate final remaining
    result[:remaining_funds] = calculate_total_remaining(income_schedule, result[:allocations])

    result
  end

  private

  def build_income_schedule
    schedule = []
    user.incomes.each do |income|
      dates = income.occurrences_until(end_date)
      dates.each do |date|
        schedule << {
          date: date,
          amount: income.amount,
          description: income.description,
          income_id: income.id
        }
      end
    end
    schedule.sort_by { |s| s[:date] }
  end

  def build_expense_schedule
    user.expenses.future.map do |expense|
      {
        date: expense.expense_date,
        amount: expense.amount,
        description: expense.description,
        expense_id: expense.id
      }
    end
  end

  def allocate_for_target_date(item, income_schedule)
    target_date = item.target_date
    needed = item.remaining_cost
    allocated = []
    total_allocated = 0

    # Build complete timeline of income and expenses
    events = []
    income_schedule.each { |i| events << { date: i[:date], amount: i[:amount], type: :income } }
    user.expenses.future.each { |e| events << { date: e.expense_date, amount: e.amount, type: :expense } }
    events.sort_by! { |e| e[:date] }

    # Find the earliest date where we can afford the item AND maintain positive balance afterward
    # Group events by date to get end-of-day balances
    feasible_date = nil

    # Get unique dates from events
    unique_dates = events.map { |e| e[:date] }.uniq.sort

    unique_dates.each do |check_date|
      next if check_date > target_date  # Don't check dates after target for initial feasibility

      # Calculate balance at END of this date (after all events on this date)
      balance_at_end_of_day = 0
      events.each do |e|
        break if e[:date] > check_date
        balance_at_end_of_day += (e[:type] == :income ? e[:amount] : -e[:amount])
      end

      # Check if we have enough at end of day to buy the item
      next if balance_at_end_of_day < needed

      # Simulate buying the item at end of this date
      balance_after_purchase = balance_at_end_of_day - needed

      # Check if we stay positive through all future events
      future_min_balance = balance_after_purchase
      events.each do |future_event|
        next if future_event[:date] <= check_date  # Skip events up to and including check date
        balance_after_purchase += (future_event[:type] == :income ? future_event[:amount] : -future_event[:amount])
        future_min_balance = [future_min_balance, balance_after_purchase].min
      end

      # If we never go negative, this date works
      if future_min_balance >= 0
        feasible_date = check_date
        break
      end
    end

    # Filter income up to feasible date (or target date if checking)
    check_date = feasible_date || target_date
    available = income_schedule.select { |i| i[:date] <= check_date }

    if feasible_date && feasible_date <= target_date
      # Distribute evenly across available income dates
      per_income = needed / available.size
      available.each do |income|
        amount = [per_income, income[:amount], needed - total_allocated].min
        allocated << {
          date: income[:date],
          amount: amount.round(2),
          income_id: income[:income_id]
        }
        total_allocated += amount
        break if total_allocated >= needed
      end

      {
        item_id: item.id,
        item_name: item.name,
        item_cost: item.cost,
        amount_allocated: total_allocated.round(2),
        funded_by: allocated,
        feasible: true,
        completion_date: allocated.last[:date],
        target_date: item.target_date
      }
    else
      # Target date not feasible - find next available date where we can buy AND stay positive
      next_completion_date = nil

      # Check all unique dates (using end-of-day balances)
      unique_dates.each do |check_date|
        # Calculate balance at END of this date (after all events on this date)
        balance_at_end_of_day = 0
        events.each do |e|
          break if e[:date] > check_date
          balance_at_end_of_day += (e[:type] == :income ? e[:amount] : -e[:amount])
        end

        # Check if we have enough at end of day to buy the item
        next if balance_at_end_of_day < needed

        # Simulate buying the item at end of this date
        balance_after_purchase = balance_at_end_of_day - needed

        # Check if we stay positive through all future events
        future_min_balance = balance_after_purchase
        events.each do |future_event|
          next if future_event[:date] <= check_date  # Skip events up to and including check date
          balance_after_purchase += (future_event[:type] == :income ? future_event[:amount] : -future_event[:amount])
          future_min_balance = [future_min_balance, balance_after_purchase].min
        end

        # If we never go negative, this date works
        if future_min_balance >= 0
          next_completion_date = check_date
          break
        end
      end

      # If we found a completion date after target, allocate to that date
      if next_completion_date
        available_extended = income_schedule.select { |i| i[:date] <= next_completion_date }
        per_income = needed / available_extended.size

        available_extended.each do |income|
          amount = [per_income, income[:amount], needed - total_allocated].min
          allocated << {
            date: income[:date],
            amount: amount.round(2),
            income_id: income[:income_id]
          }
          total_allocated += amount
          break if total_allocated >= needed
        end

        {
          item_id: item.id,
          item_name: item.name,
          item_cost: item.cost,
          amount_allocated: total_allocated.round(2),
          funded_by: allocated,
          feasible: true,
          completion_date: next_completion_date,
          target_date: item.target_date,
          adjusted: true,
          original_target: item.target_date
        }
      else
        # Still not enough even with all income minus expenses
        total_income = income_schedule.sum { |i| i[:amount] }
        total_expenses = user.expenses.future.sum(:amount)
        net_total = total_income - total_expenses

        {
          item_id: item.id,
          item_name: item.name,
          item_cost: item.cost,
          amount_allocated: 0,
          funded_by: [],
          feasible: false,
          shortfall: (needed - net_total).round(2),
          target_date: item.target_date
        }
      end
    end
  end

  def allocate_sequential(item, net_by_date, existing_allocations)
    needed = item.remaining_cost
    allocated = []
    total_allocated = 0

    # Build complete timeline of income, expenses, AND existing allocations to check future balances
    events = []
    user.incomes.each do |income|
      income.occurrences_until(end_date).each do |date|
        events << { date: date, amount: income.amount, type: :income }
      end
    end
    user.expenses.future.each do |expense|
      events << { date: expense.expense_date, amount: expense.amount, type: :expense }
    end

    # Add existing allocations as future purchases
    existing_allocations.each do |allocation|
      if allocation[:completion_date] && allocation[:amount_allocated] && allocation[:amount_allocated] > 0
        events << { date: allocation[:completion_date], amount: allocation[:amount_allocated], type: :wishlist }
      end
    end

    events.sort_by! { |e| e[:date] }

    # Get unique dates sorted
    unique_dates = events.map { |e| e[:date] }.uniq.sort

    # Find the earliest date where we can afford the full item AND maintain positive balance afterward
    completion_date = nil

    unique_dates.each do |check_date|
      # Calculate balance at END of this date (after all events on this date)
      balance_at_end_of_day = 0
      events.each do |e|
        break if e[:date] > check_date
        case e[:type]
        when :income
          balance_at_end_of_day += e[:amount]
        when :expense, :wishlist
          balance_at_end_of_day -= e[:amount]
        end
      end

      # Check if we have enough at end of day to buy the full item
      next if balance_at_end_of_day < needed

      # Simulate buying the item at end of this date
      balance_after_purchase = balance_at_end_of_day - needed

      # Check if we stay positive through all future events
      future_min_balance = balance_after_purchase
      events.each do |future_event|
        next if future_event[:date] <= check_date
        case future_event[:type]
        when :income
          balance_after_purchase += future_event[:amount]
        when :expense, :wishlist
          balance_after_purchase -= future_event[:amount]
        end
        future_min_balance = [future_min_balance, balance_after_purchase].min
      end

      # If we never go negative, this date works
      if future_min_balance >= 0
        completion_date = check_date
        break
      end
    end

    # If we found a feasible date, allocate the full amount to that date
    if completion_date
      allocated << {
        date: completion_date,
        amount: needed.round(2)
      }
      total_allocated = needed
    end

    {
      item_id: item.id,
      item_name: item.name,
      item_cost: item.cost,
      amount_allocated: total_allocated.round(2),
      funded_by: allocated,
      completion_date: completion_date
    }
  end

  def allocate_by_percentage(item, net_by_date, weight, existing_allocations)
    needed = item.remaining_cost
    allocated = []
    total_allocated = 0

    # Build complete timeline of income, expenses, AND existing allocations to check future balances
    events = []
    user.incomes.each do |income|
      income.occurrences_until(end_date).each do |date|
        events << { date: date, amount: income.amount, type: :income }
      end
    end
    user.expenses.future.each do |expense|
      events << { date: expense.expense_date, amount: expense.amount, type: :expense }
    end

    # Add existing allocations as future purchases
    existing_allocations.each do |allocation|
      if allocation[:completion_date] && allocation[:amount_allocated] && allocation[:amount_allocated] > 0
        events << { date: allocation[:completion_date], amount: allocation[:amount_allocated], type: :wishlist }
      end
    end

    events.sort_by! { |e| e[:date] }

    # Get unique dates sorted
    unique_dates = events.map { |e| e[:date] }.uniq.sort

    # Find the earliest date where we can afford the full item AND maintain positive balance afterward
    completion_date = nil

    unique_dates.each do |check_date|
      # Calculate balance at END of this date (after all events on this date)
      balance_at_end_of_day = 0
      events.each do |e|
        break if e[:date] > check_date
        case e[:type]
        when :income
          balance_at_end_of_day += e[:amount]
        when :expense, :wishlist
          balance_at_end_of_day -= e[:amount]
        end
      end

      # Check if we have enough at end of day to buy the full item
      next if balance_at_end_of_day < needed

      # Simulate buying the item at end of this date
      balance_after_purchase = balance_at_end_of_day - needed

      # Check if we stay positive through all future events
      future_min_balance = balance_after_purchase
      events.each do |future_event|
        next if future_event[:date] <= check_date
        case future_event[:type]
        when :income
          balance_after_purchase += future_event[:amount]
        when :expense, :wishlist
          balance_after_purchase -= future_event[:amount]
        end
        future_min_balance = [future_min_balance, balance_after_purchase].min
      end

      # If we never go negative, this date works
      if future_min_balance >= 0
        completion_date = check_date
        break
      end
    end

    # If we found a feasible date, allocate the full amount to that date
    if completion_date
      allocated << {
        date: completion_date,
        amount: needed.round(2)
      }
      total_allocated = needed
    end

    {
      item_id: item.id,
      item_name: item.name,
      item_cost: item.cost,
      percentage: item.percentage,
      amount_allocated: total_allocated.round(2),
      funded_by: allocated,
      completion_date: completion_date
    }
  end

  def calculate_remaining_funds(income_schedule, allocations)
    # Build a timeline of all financial events by date (net changes per date)
    net_by_date = {}

    # Add all income
    income_schedule.each do |income|
      net_by_date[income[:date]] ||= 0
      net_by_date[income[:date]] += income[:amount]
    end

    # Subtract future expenses
    user.expenses.future.each do |expense|
      net_by_date[expense.expense_date] ||= 0
      net_by_date[expense.expense_date] -= expense.amount
    end

    # Subtract all allocations
    allocations.each do |allocation|
      next unless allocation[:funded_by]

      allocation[:funded_by].each do |funding|
        net_by_date[funding[:date]] ||= 0
        net_by_date[funding[:date]] -= funding[:amount]
      end
    end

    net_by_date.sort.to_h
  end

  def calculate_total_remaining(income_schedule, allocations)
    total_income = income_schedule.sum { |i| i[:amount] }
    total_expenses = user.expenses.future.sum(:amount)
    total_allocated = allocations.sum { |a| a[:amount_allocated] || 0 }
    (total_income - total_expenses - total_allocated).round(2)
  end
end
