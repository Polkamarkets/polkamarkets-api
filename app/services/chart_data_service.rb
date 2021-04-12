class ChartDataService
  attr_accessor :items_arr, :item_key

  TIMEFRAMES = {
    "1h" => 1.hours,
    "4h" => 4.hours,
    "1d" => 1.day,
    "1m" => 1.month
  }

  def initialize(items_arr, item_key)
    # sorting array by timestamp (high -> low)
    @items_arr = items_arr.sort_by { |item| -item[:timestamp] }
    @item_key = item_key
  end

  def chart_data_for(timeframe, candles = 12)
    timestamps = timestamps_for(timeframe, candles)

    values_at_timestamps(timestamps)
  end

  def value_at(timestamp)
    # taking into assumption that price_arr was previously sorted (high -> low)
    items_arr.find { |item| item[:timestamp] < timestamp }
  end

  def timestamps_for(timeframe, candles = 12)
    # returns previous datetime for each candle (last one corresponding to now)
    initial_datetime = self.class.previous_datetime_for(timeframe)

    # adding now as last candle
    timestamps = [DateTime.now.to_i]

    # subracting one candle (last candle -> now)
    (candles - 1).times do |index|
      timestamp = (initial_datetime - TIMEFRAMES[timeframe] * index).to_i

      timestamps.push(timestamp)
    end

    timestamps
  end

  def values_at_timestamps(timestamps)
    # taking into assumption that price_arr was previously sorted (high -> low)
    values = []

    for timestamp in timestamps do
      item = value_at(timestamp)
      # no more data backwards
      break if item.blank?

      values.push({ value: item[item_key], timestamp: timestamp, date: Time.at(timestamp) })
    end

    values.reverse
  end

  def self.previous_datetime_for(timeframe)
    # TODO: double check timezones issue
    case timeframe
    when '1h'
      DateTime.now.beginning_of_hour
    when '4h'
      datetime = DateTime.now.beginning_of_hour
      # making sure hour is a multiple of four
      until datetime.hour % 4 == 0 do
        datetime = datetime - 1.hour
      end
      datetime
    when '1d'
      DateTime.now.beginning_of_day
    when '1m'
      DateTime.now.beginning_of_month
    else
      raise "ChartDataService :: Timeframe #{timeframe} not supported"
    end
  end

  def self.next_datetime_for(timeframe)
    previous_datetime_for(timeframe) + TIMEFRAMES[timeframe]
  end
end
