class IncomesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_income, only: [:edit, :update, :destroy]

  def index
    @incomes = current_user.incomes.order(created_at: :desc)
  end

  def new
    @income = current_user.incomes.build
  end

  def create
    @income = current_user.incomes.build(income_params)

    if @income.save
      redirect_to incomes_path, notice: "Income was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @income.update(income_params)
      redirect_to incomes_path, notice: "Income was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @income.destroy
    redirect_to incomes_path, notice: "Income was successfully deleted."
  end

  private

  def set_income
    @income = current_user.incomes.find(params[:id])
  end

  def income_params
    params.require(:income).permit(:description, :amount, :frequency, :frequency_day, :start_date)
  end
end
