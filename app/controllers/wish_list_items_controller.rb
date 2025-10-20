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

    if @wish_list_item.save
      redirect_to wish_list_items_path, notice: "Wish list item was successfully created."
    else
      render :new, status: :unprocessable_entity
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
    @wish_list_item.destroy
    redirect_to wish_list_items_path, notice: "Wish list item was successfully deleted."
  end

  def mark_as_purchased
    if @wish_list_item.mark_as_purchased!(@wish_list_item.cost)
      redirect_to wish_list_items_path, notice: "Item marked as purchased!"
    else
      redirect_to wish_list_items_path, alert: "Failed to mark item as purchased."
    end
  end

  private

  def set_wish_list_item
    @wish_list_item = current_user.wish_list_items.find(params[:id])
  end

  def wish_list_item_params
    params.require(:wish_list_item).permit(:name, :cost, :item_type, :target_date, :sequential_order, :percentage)
  end
end
