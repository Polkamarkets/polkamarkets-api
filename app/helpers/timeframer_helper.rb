module TimeframerHelper
  TIMEFRAMES = {
    'at' => 'all-time',
    '1d' => 'day',
    '1w' => 'week',
    '1m' => 'month'
  }.freeze

  def timestamp_from(timestamp, timeframe)
    return 0 if TIMEFRAMES[timeframe] == 'all-time'

    # weekly timeframe starts on Fridays due to the rewarding system
    args = TIMEFRAMES[timeframe] == 'week' ? [:friday] : []

    date = Time.at(timestamp).utc.public_send("beginning_of_#{TIMEFRAMES[timeframe]}", *args).to_i
  end

  def timestamp_to(timestamp, timeframe)
    # setting to next 5 minute block if timeframe is all time
    return (Time.now.to_i / 300 + 1) * 300 if TIMEFRAMES[timeframe] == 'all-time'

    # weekly timeframe starts on Fridays due to the rewarding system
    args = TIMEFRAMES[timeframe] == 'week' ? [:friday] : []

    date = Time.at(timestamp).utc.public_send("end_of_#{TIMEFRAMES[timeframe]}", *args).to_i
  end

end