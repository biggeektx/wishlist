class WishListItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_wish_list_item, only: [:edit, :update, :destroy, :mark_as_purchased]

  def index
    @wish_list_items = current_user.wish_list_items.order(created_at: :desc)
  end

  def new
    @wish_list_item = current_user.wish_list_items.build
  end

  def create
    @wish_list_item = current_user.wish_list_items.build(wish_list_item_params)

    ActiveRecord::Base.transaction do
      # Auto-bump sequential items if needed
      if @wish_list_item.item_type == 'sequential' && @wish_list_item.sequential_order.present?
        current_user.wish_list_items.unpurchased.sequential_items.where(
          'sequential_order >= ?', @wish_list_item.sequential_order
        ).order(sequential_order: :desc).each do |item|
          item.update_column(:sequential_order, item.sequential_order + 1)
        end
      end

      # Rebalance percentage items if needed
      if @wish_list_item.item_type == 'percentage' && @wish_list_item.percentage.present?
        existing_percentage_items = current_user.wish_list_items.unpurchased.percentage_items.to_a

        if existing_percentage_items.any?
          # Calculate remaining percentage after new item
          remaining_percent = 100.0 - @wish_list_item.percentage

          # Get current total of existing items
          current_total = existing_percentage_items.sum(&:percentage)

          # Rebalance existing items proportionally
          existing_percentage_items.each do |item|
            # Calculate this item's proportion of the current total
            proportion = item.percentage / current_total
            # Assign it that proportion of the remaining percentage
            new_percentage = (remaining_percent * proportion).round(2)
            item.update_column(:percentage, new_percentage)
          end
        end
      end

      # For target date items, check if we need to adjust other target dates
      if @wish_list_item.item_type == 'target_date' && @wish_list_item.target_date.present?
        # Run allocation to see actual completion dates
        if @wish_list_item.save
          calculator = AllocationCalculator.new(current_user)
          result = calculator.calculate

          # Update any target date items that got pushed out
          result[:allocations].each do |allocation|
            if allocation[:adjusted] && allocation[:item_id]
              item = current_user.wish_list_items.find_by(id: allocation[:item_id])
              if item && item.target_date && allocation[:completion_date] > item.target_date
                # Target date is no longer feasible, update to next available date
                item.update_column(:target_date, allocation[:completion_date])
              end
            end
          end
        end
      else
        @wish_list_item.save
      end
    end

    if @wish_list_item.persisted?
      respond_to do |format|
        format.html { redirect_to wish_list_items_path, notice: "Wish list item was successfully created." }
        format.json { render json: { success: true, message: "Wish list item was successfully created." }, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { success: false, errors: @wish_list_item.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    if @wish_list_item.update(wish_list_item_params)
      redirect_to wish_list_items_path, notice: "Wish list item was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    ActiveRecord::Base.transaction do
      # If deleting a sequential item, shift down items with higher order
      if @wish_list_item.item_type == 'sequential' && @wish_list_item.sequential_order.present?
        current_user.wish_list_items.unpurchased.sequential_items.where(
          'sequential_order > ?', @wish_list_item.sequential_order
        ).order(sequential_order: :asc).each do |item|
          item.update_column(:sequential_order, item.sequential_order - 1)
        end
      end

      # If deleting a percentage item, rebalance remaining items
      if @wish_list_item.item_type == 'percentage' && @wish_list_item.percentage.present?
        deleted_percentage = @wish_list_item.percentage
        remaining_items = current_user.wish_list_items.unpurchased.percentage_items.where.not(id: @wish_list_item.id).to_a

        if remaining_items.any?
          # Get current total of remaining items (before rebalancing)
          current_total = remaining_items.sum(&:percentage)

          # Redistribute the deleted percentage proportionally
          remaining_items.each do |item|
            proportion = item.percentage / current_total
            new_percentage = (item.percentage + (deleted_percentage * proportion)).round(2)
            item.update_column(:percentage, new_percentage)
          end
        end
      end

      @wish_list_item.destroy
    end
    redirect_to wish_list_items_path, notice: "Wish list item was successfully deleted."
  end

  def mark_as_purchased
    amount = params[:amount]&.to_f || @wish_list_item.cost

    if @wish_list_item.mark_as_purchased!(amount)
      respond_to do |format|
        format.html { redirect_to wish_list_items_path, notice: "Item marked as purchased!" }
        format.json { render json: { success: true, message: "Item marked as purchased!" }, status: :ok }
      end
    else
      respond_to do |format|
        format.html { redirect_to wish_list_items_path, alert: "Failed to mark item as purchased." }
        format.json { render json: { success: false, error: "Failed to mark item as purchased." }, status: :unprocessable_entity }
      end
    end
  end

  def preview
    # Create a temporary item (not saved to database)
    temp_item = current_user.wish_list_items.build(
      name: params[:name],
      cost: params[:cost].present? ? params[:cost].to_f : 0,
      item_type: params[:item_type],
      target_date: params[:target_date].present? ? Date.parse(params[:target_date]) : nil,
      sequential_order: params[:sequential_order].present? ? params[:sequential_order].to_i : nil,
      percentage: params[:percentage].present? ? params[:percentage].to_f : nil
    )

    # For sequential items, simulate the bumping of existing items
    bumped_sequential = nil
    if temp_item.item_type == 'sequential' && temp_item.sequential_order.present?
      bumped_sequential = []
      current_user.wish_list_items.unpurchased.sequential_items.each do |item|
        if item.sequential_order >= temp_item.sequential_order
          # Create a duplicate with bumped order for preview
          bumped = item.dup
          bumped.sequential_order = item.sequential_order + 1
          bumped_sequential << bumped
        else
          bumped_sequential << item
        end
      end
    end

    # For percentage items, simulate the rebalancing
    rebalanced_percentages = nil
    if temp_item.item_type == 'percentage' && temp_item.percentage.present?
      existing_items = current_user.wish_list_items.unpurchased.percentage_items.to_a

      if existing_items.any?
        rebalanced_percentages = []
        remaining_percent = 100.0 - temp_item.percentage
        current_total = existing_items.sum(&:percentage)

        # Only rebalance if current_total is positive
        if current_total && current_total > 0
          existing_items.each do |item|
            rebalanced = item.dup
            proportion = item.percentage / current_total
            rebalanced.percentage = (remaining_percent * proportion).round(2)
            rebalanced_percentages << rebalanced
          end
        end
      end
    end

    # Run allocation with temp item included and bumped sequential/percentage items (if applicable)
    calculator = AllocationCalculator.new(
      current_user,
      2.years.from_now.to_date,
      temp_items: [temp_item],
      bumped_sequential: bumped_sequential,
      rebalanced_percentages: rebalanced_percentages
    )
    result = calculator.calculate

    # Find the preview item in the result
    preview_allocation = result[:allocations].find { |a| a[:item_name] == temp_item.name }

    # Render timeline partial with filter params
    timeline_html = render_to_string(
      partial: 'dashboard/timeline',
      locals: {
        allocation_result: result,
        params: params  # Pass params so timeline can maintain filter state
      },
      formats: [:html]
    )

    # Build preview summary showing impact on all items
    item_html = if preview_allocation
      color = temp_item.item_type == 'target_date' ? 'red' : temp_item.item_type == 'sequential' ? 'blue' : 'green'

      if preview_allocation[:completion_date]
        "<div class='bg-#{color}-50 border border-#{color}-200 rounded-lg p-4'>
          <h4 class='font-semibold text-#{color}-900 mb-3'>Adding: #{temp_item.name}</h4>
          <div class='space-y-1'>
            <p class='text-sm text-#{color}-700'>Cost: #{view_context.number_to_currency(temp_item.cost)}</p>
            <p class='text-sm text-#{color}-700'>Type: #{temp_item.item_type.humanize}</p>
            <p class='text-sm font-semibold text-#{color}-800 mt-2'>Would be fully funded by: #{preview_allocation[:completion_date].strftime('%B %d, %Y')}</p>
          </div>
          <p class='text-xs text-#{color}-600 mt-3 pt-3 border-t border-#{color}-300'>💡 Check the timeline above to see how this affects your other items</p>
        </div>"
      elsif preview_allocation[:feasible] == false
        "<div class='bg-red-50 border border-red-200 rounded-lg p-4'>
          <h4 class='font-semibold text-red-900 mb-3'>Adding: #{temp_item.name}</h4>
          <div class='space-y-1'>
            <p class='text-sm text-red-700'>Cost: #{view_context.number_to_currency(temp_item.cost)}</p>
            <p class='text-sm text-red-700'>⚠️ Cannot meet target date with current income</p>
            <p class='text-sm text-red-600 mt-2'>Shortfall: #{view_context.number_to_currency(preview_allocation[:shortfall])}</p>
          </div>
        </div>"
      else
        "<div class='bg-gray-50 border border-gray-200 rounded-lg p-4'>
          <p class='text-sm text-gray-600'>Unable to calculate funding timeline</p>
        </div>"
      end
    else
      "<div class='bg-gray-50 border border-gray-200 rounded-lg p-4'>
        <p class='text-sm text-gray-600'>Unable to calculate funding timeline</p>
      </div>"
    end

    render json: { html: item_html, timeline: timeline_html }
  end

  private

  def set_wish_list_item
    @wish_list_item = current_user.wish_list_items.find(params[:id])
  end

  def wish_list_item_params
    params.require(:wish_list_item).permit(:name, :cost, :item_type, :target_date, :sequential_order, :percentage)
  end
end
