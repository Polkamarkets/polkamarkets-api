class ChartDataService
  attr_accessor :items_arr, :item_key

  TIMEFRAMES = {
    "1h" => 1.hours,
    "24h" => 24.hours,
    "30d" => 30.days,
    "all" => 30.days # TODO: for now we'll use the same logic as 30d
  }

  def initialize(items_arr, item_key)
    # sorting array by timestamp (high -> low)
    @items_arr = items_arr.sort_by { |item| -item[:timestamp] }
    @item_key = item_key
  end

  def chart_data_for(timeframe, candles = 12)
    timestamps = self.class.timestamps_for(timeframe, candles)

    values_at_timestamps(timestamps)
  end

  def value_at(timestamp)
    # taking into assumption that price_arr was previously sorted (high -> low)
    items_arr.find { |item| item[:timestamp] < timestamp }
  end

  def self.timestamps_for(timeframe, candles = 12)
    # returns previous datetime for each candle (last one corresponding to now)
    initial_datetime = previous_datetime_for(timeframe)

    # adding now as last candle
    timestamps = [DateTime.now.to_i]

    # calculating number of candles
    step = step_for(timeframe)
    points = TIMEFRAMES[timeframe] / step

    # subracting one candle (last candle -> now)
    points.times do |index|
      timestamp = (initial_datetime - step * index).to_i

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

  def self.step_for(timeframe)
    case timeframe
    when '1h' # 12 candles
      5.minutes
    when '24h' # 24 candles
      1.hour
    when '30d' # 30 candles
      1.day
    when 'all'
      1.day
    else
      raise "ChartDataService :: Timeframe #{timeframe} not supported"
    end
  end

  def self.previous_datetime_for(timeframe)
    # TODO: double check timezones issue
    case timeframe
    when '1h'
      datetime = DateTime.now.beginning_of_minute
      # making sure minute is a multiple of 5
      until datetime.minute % 5 == 0 do
        datetime = datetime - 1.minute
      end
      datetime
    when '24h'
      datetime = DateTime.now.beginning_of_hour
    when '30d'
      DateTime.now.beginning_of_day
    when 'all'
      DateTime.now.beginning_of_day
    else
      raise "ChartDataService :: Timeframe #{timeframe} not supported"
    end
  end

  def self.next_datetime_for(timeframe)
    previous_datetime_for(timeframe) + step_for(timeframe)
  end
end
