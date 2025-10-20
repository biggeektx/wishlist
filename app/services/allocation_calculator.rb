class AllocationCalculator
  attr_reader :user, :end_date

  def initialize(user, end_date = 2.years.from_now.to_date)
    @user = user
    @end_date = end_date
  end

  def calculate
    # Get all future income
    income_schedule = build_income_schedule

    # Get future expenses
    expense_schedule = build_expense_schedule

    # Get all unpurchased items
    target_items = user.wish_list_items.unpurchased.target_date_items.order(:target_date)
    sequential_items = user.wish_list_items.unpurchased.sequential_items
    percentage_items = user.wish_list_items.unpurchased.percentage_items

    # Initialize result structure
    result = {
      total_income: income_schedule.sum { |i| i[:amount] },
      total_expenses: expense_schedule.sum { |e| e[:amount] },
      allocations: [],
      expenses: expense_schedule,
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
      allocation = allocate_sequential(item, remaining_by_date)
      result[:allocations] << allocation
      result[:timeline] << {
        item: item,
        funded_by: allocation[:funded_by],
        type: "sequential"
      }
    end

    # Recalculate remaining after sequential
    remaining_by_date = calculate_remaining_funds(income_schedule, result[:allocations])

    # Phase 3: Allocate remaining by percentage
    if percentage_items.any?
      total_percentage = percentage_items.sum(:percentage)
      percentage_items.each do |item|
        weight = item.percentage / total_percentage
        allocation = allocate_by_percentage(item, remaining_by_date, weight)
        result[:allocations] << allocation
        result[:timeline] << {
          item: item,
          funded_by: allocation[:funded_by],
          type: "percentage"
        }
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

    # Filter income up to target date
    available = income_schedule.select { |i| i[:date] <= target_date }
    total_available = available.sum { |i| i[:amount] }

    if total_available >= needed
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
        completion_date: allocated.last[:date]
      }
    else
      # Not enough income by target date
      {
        item_id: item.id,
        item_name: item.name,
        item_cost: item.cost,
        amount_allocated: 0,
        funded_by: [],
        feasible: false,
        shortfall: (needed - total_available).round(2)
      }
    end
  end

  def allocate_sequential(item, remaining_funds)
    needed = item.remaining_cost
    allocated = []
    total_allocated = 0

    remaining_funds.each do |date, amount|
      next if amount <= 0

      allocation_amount = [amount, needed - total_allocated].min
      allocated << {
        date: date,
        amount: allocation_amount.round(2)
      }
      remaining_funds[date] -= allocation_amount
      total_allocated += allocation_amount

      break if total_allocated >= needed
    end

    {
      item_id: item.id,
      item_name: item.name,
      item_cost: item.cost,
      amount_allocated: total_allocated.round(2),
      funded_by: allocated,
      completion_date: allocated.any? ? allocated.last[:date] : nil
    }
  end

  def allocate_by_percentage(item, remaining_funds, weight)
    needed = item.remaining_cost
    allocated = []
    total_allocated = 0

    remaining_funds.each do |date, amount|
      next if amount <= 0

      # Allocate proportionally based on weight
      allocation_amount = [amount * weight, needed - total_allocated].min
      if allocation_amount > 0
        allocated << {
          date: date,
          amount: allocation_amount.round(2)
        }
        remaining_funds[date] -= allocation_amount
        total_allocated += allocation_amount
      end

      break if total_allocated >= needed
    end

    {
      item_id: item.id,
      item_name: item.name,
      item_cost: item.cost,
      percentage: item.percentage,
      amount_allocated: total_allocated.round(2),
      funded_by: allocated,
      completion_date: allocated.any? ? allocated.last[:date] : nil
    }
  end

  def calculate_remaining_funds(income_schedule, allocations)
    remaining = {}

    # Initialize with all income
    income_schedule.each do |income|
      remaining[income[:date]] ||= 0
      remaining[income[:date]] += income[:amount]
    end

    # Subtract future expenses
    user.expenses.future.each do |expense|
      remaining[expense.expense_date] ||= 0
      remaining[expense.expense_date] -= expense.amount
    end

    # Subtract all allocations
    allocations.each do |allocation|
      next unless allocation[:funded_by]

      allocation[:funded_by].each do |funding|
        remaining[funding[:date]] ||= 0
        remaining[funding[:date]] -= funding[:amount]
      end
    end

    remaining.sort.to_h
  end

  def calculate_total_remaining(income_schedule, allocations)
    total_income = income_schedule.sum { |i| i[:amount] }
    total_expenses = user.expenses.future.sum(:amount)
    total_allocated = allocations.sum { |a| a[:amount_allocated] || 0 }
    (total_income - total_expenses - total_allocated).round(2)
  end
end
