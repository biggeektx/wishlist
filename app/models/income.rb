class Income < ApplicationRecord
  belongs_to :user

  FREQUENCIES = {
    "one_time" => "One-time income (e.g., birthday gift, bonus)",
    "specific_date" => "Specific date each month (e.g., 15th)",
    "last_day" => "Last day of the month",
    "biweekly" => "Every other week (e.g., every other Friday)"
  }.freeze

  validates :description, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :frequency, presence: true, inclusion: { in: FREQUENCIES.keys }
  validates :frequency_day, presence: true, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 31 },
            if: -> { frequency == "specific_date" }
  validates :start_date, presence: true, if: -> { frequency == "biweekly" }
  validates :one_time_date, presence: true, if: -> { frequency == "one_time" }

  # Generate income occurrences for the next N months
  def occurrences_until(end_date)
    dates = []
    current_date = start_date || Date.current

    case frequency
    when "one_time"
      # Single occurrence on the specified date
      if one_time_date && one_time_date >= Date.current && one_time_date <= end_date
        dates << one_time_date
      end
    when "specific_date"
      # Income on a specific day each month
      while current_date <= end_date
        target_date = Date.new(current_date.year, current_date.month, [frequency_day, current_date.end_of_month.day].min)
        dates << target_date if target_date >= Date.current && target_date <= end_date
        current_date = current_date.next_month
      end
    when "last_day"
      # Income on the last day of each month
      while current_date <= end_date
        target_date = current_date.end_of_month
        dates << target_date if target_date >= Date.current && target_date <= end_date
        current_date = current_date.next_month
      end
    when "biweekly"
      # Income every 2 weeks from start_date
      current_date = start_date
      while current_date <= end_date
        dates << current_date if current_date >= Date.current
        current_date += 14.days
      end
    end

    dates.sort
  end
end
