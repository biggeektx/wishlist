class Expense < ApplicationRecord
  belongs_to :user

  validates :description, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :expense_date, presence: true

  scope :ordered, -> { order(expense_date: :desc) }
  scope :recent, -> { ordered.limit(10) }
  scope :future, -> { where("expense_date >= ?", Date.current).order(:expense_date) }
  scope :past, -> { where("expense_date < ?", Date.current).ordered }
end
