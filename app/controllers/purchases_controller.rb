class PurchasesController < ApplicationController
  before_action :authenticate_user!

  def index
    @purchases = current_user.purchases.includes(:wish_list_item).ordered
  end
end
