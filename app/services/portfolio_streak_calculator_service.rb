class PortfolioStreakCalculatorService
  attr_reader :portfolio_id, :tournament_group_id

  def initialize(portfolio_id, tournament_group_id)
    @portfolio_id = portfolio_id
    @tournament_group_id = tournament_group_id
  end

  def get_current_streak
    calculate_streaks(current: true)
  end

  def calculate_streaks(refresh: false, current: false)
    return unless tournament_group_id.present? && portfolio_id.present?

    tournament_group = TournamentGroup.find(tournament_group_id)
    portfolio = Portfolio.find(portfolio_id)

    raise 'Land does not have streaks enabled' unless tournament_group.streaks_enabled?

    action_events = portfolio.action_events(refresh: refresh)
    market_ids = tournament_group.markets.pluck(:eth_market_id).uniq.compact
    streaks_values = tournament_group.streaks_config["values"]

    action_events.select! { |action_event| market_ids.include?(action_event[:market_id]) }
    return empty_streak(streaks_values) if action_events.empty?

    streak = {
      streaks: 0,
      claimed: 0,
      to_claim: 0,
      values: []
    }

    # creating array of all days since first action
    all_days = (Time.at(action_events.map { |a| a[:timestamp] }.min).to_date..Date.today).to_a

    # creating array of all days with action
    days_with_action = action_events.map { |a| Time.at(a[:timestamp]).to_date }.uniq

    streak_index = 0

    all_days.each_with_index do |day, index|
      value = {
        date: day,
        value: 0,
        completed: false,
        is_streak: false,
        is_streak_end: false,
        pending: false
      }

      value[:value] = streaks_values[streak_index]
      if days_with_action.include?(day)
        streak_index = (streak_index + 1) % streaks_values.size
        streak_completed = streak_index == 0
        value[:completed] = true
        value[:is_streak_end] = true if streak_completed
        streak[:streaks] += 1 if streak_completed
        streak[:to_claim] += value[:value]
        # TODO streak[:claimed]
      else
        streak_index = 0
        if DateTime.now.to_date == day
          value[:pending] = true
          streak_index = (streak_index + 1) % streaks_values.size
        end
      end

      streak[:values] << value

      if value[:is_streak_end]
        # backfilling previous days
        streak[:values].last(streaks_values.size).each do |v|
          v[:is_streak] = true
        end
      end
    end

    return streak unless current

    # only showing values since last miss (including last miss)
    last_miss = streak[:values].reverse.find { |v| !v[:completed] }
    if last_miss
      streak[:values].select! { |v| v[:date] >= last_miss[:date] }
    end

    if streak[:values].count >= streaks_values.size
      streak[:values] = streak[:values].last(streaks_values.size)
    else
      # adding future days
      (streaks_values.size - streak[:values].count).times do
        streak[:values] << {
          date: streak[:values].last[:date] + 1.day,
          value: streaks_values[streak_index],
          completed: false,
          is_streak: false,
          is_streak_end: false,
          pending: false
        }
        streak_index = (streak_index + 1) % streaks_values.size
      end
    end

    streak
  end

  def empty_streak(streaks_config)
    {
      streaks: 0,
      claimed: 0,
      to_claim: 0,
      values: streaks_config.each_with_index.map do |value, index|
        {
          date: DateTime.now.to_date + index.days,
          value: value,
          completed: false,
          is_streak: false,
          is_streak_end: false,
          pending: index == 0
        }
      end
    }
  end
end
