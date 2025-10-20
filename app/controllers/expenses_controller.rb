class ExpensesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_expense, only: [:edit, :update, :destroy]

  def index
    @expenses = current_user.expenses.ordered
  end

  def new
    @expense = current_user.expenses.build(expense_date: Date.current)
  end

  def create
    @expense = current_user.expenses.build(expense_params)

    if @expense.save
      redirect_to expenses_path, notice: "Expense was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @expense.update(expense_params)
      redirect_to expenses_path, notice: "Expense was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @expense.destroy
    redirect_to expenses_path, notice: "Expense was successfully deleted."
  end

  private

  def set_expense
    @expense = current_user.expenses.find(params[:id])
  end

  def expense_params
    params.require(:expense).permit(:description, :amount, :expense_date)
  end
end
