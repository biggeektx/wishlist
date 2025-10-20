class WishListItem < ApplicationRecord
  belongs_to :user
  has_many :purchases, dependent: :destroy

  validates :name, presence: true
  validates :cost, presence: true, numericality: { greater_than: 0 }
  validates :item_type, presence: true, inclusion: { in: %w[target_date sequential percentage] }
  validates :target_date, presence: true, if: -> { item_type == "target_date" }
  validates :sequential_order, presence: true, numericality: { only_integer: true, greater_than: 0 }, if: -> { item_type == "sequential" }
  validates :percentage, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }, if: -> { item_type == "percentage" }

  scope :unpurchased, -> { where(purchased: false) }
  scope :purchased, -> { where(purchased: true) }
  scope :target_date_items, -> { where(item_type: "target_date") }
  scope :sequential_items, -> { where(item_type: "sequential").order(:sequential_order) }
  scope :percentage_items, -> { where(item_type: "percentage") }

  def mark_as_purchased!(amount, notes = nil)
    transaction do
      update!(purchased: true, purchased_at: Time.current)
      purchases.create!(user: user, amount: amount, purchased_at: Time.current, notes: notes)
    end
  end

  def amount_saved
    purchases.sum(:amount)
  end

  def remaining_cost
    cost - amount_saved
  end
end
