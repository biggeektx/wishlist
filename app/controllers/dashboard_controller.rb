class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @wish_list_items = current_user.wish_list_items.unpurchased
    @incomes = current_user.incomes
    @recent_purchases = current_user.purchases.recent

    if @incomes.any? && @wish_list_items.any?
      calculator = AllocationCalculator.new(current_user)
      @allocation_result = calculator.calculate
    end
  end
end
