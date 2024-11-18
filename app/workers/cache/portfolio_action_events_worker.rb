class Cache::PortfolioActionEventsWorker
  include Sidekiq::Worker

  def perform(portfolio_id)
    portfolio = Portfolio.find_by(id: portfolio_id)
    return if portfolio.blank?

    portfolio.action_events(refresh: true)
    # forcing portfolio holdings_value refresh
    portfolio.holdings_value(refresh: true)
    # forcing portfolio holdings_cost refresh
    portfolio.holdings_cost(refresh: true)
    # forcing portfolio closed_markets_winnings refresh
    portfolio.closed_markets_winnings(refresh: true)
    # forcing portfolio streaks for every tournament group
    TournamentGroup.where(streaks_enabled: true).each do |tournament_group|
      portfolio.streaks(tournament_group.id, refresh: true)
    end
  end
end
