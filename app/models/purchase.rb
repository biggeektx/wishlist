class Purchase < ApplicationRecord
  belongs_to :user
  belongs_to :wish_list_item

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :purchased_at, presence: true

  scope :ordered, -> { order(purchased_at: :desc) }
  scope :recent, -> { ordered.limit(10) }
end
