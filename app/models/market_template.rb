class MarketTemplate < ApplicationRecord
  include Templatable

  validate :template_validation
  validates :template_type, presence: true

  enum template_type: {
    fear_and_greed: 0,
    tsa_checkpoint: 1,
    binance_price: 2,
    general: 3,
  }

  def template_validation
    return errors.add(:template, "must be a valid JSON object") unless template.is_a?(Hash)

    errors.add(:template, "must contain a 'title' key") unless template.key?("title")
    errors.add(:template, "must contain a 'description' key") unless template.key?("description")
    errors.add(:template, "must contain a 'resolution_source' key") unless template.key?("resolution_source")
    errors.add(:template, "must contain a 'resolution_title' key") unless template.key?("resolution_title")
    errors.add(:template, "must contain a 'outcomes' key") unless template.key?("outcomes") && template["outcomes"].is_a?(Array)
    errors.add(:template, "outcomes.length must be >= 2") unless template["outcomes"].length >= 2
    errors.add(:template, "must contain a 'outcomes.titles' key") unless template["outcomes"].all? { |outcome| outcome.is_a?(Hash) && outcome.key?("title") }
  end

  # TODO: move to separate services per template type
  def template_variables(schedule_id)
    market_schedule = MarketSchedule.find(schedule_id)

    resolution_date = market_schedule.next_run_resolves_at || DateTime.now
    schedule_template_variables = market_schedule.template_variables

    case template_type
    when "fear_and_greed"
      index_history = FearAndGreedService.get_index_history(3).map { |data| data[:value] }
      # fetching latest 3 days data and making a 70-20-10 average
      target = index_history.each_with_index.map { |value, index| value * (index == 0 ? 0.7 : index == 1 ? 0.2 : 0.1) }.sum.round

      {
        target: target,
      }
    when "tsa_checkpoint"
      index_history = TsaCheckpointService.new.get_history
      # fetching latest 7 days, comparing with 7 days before and calculating ratio
      ratio = index_history.first(7).map { |data| data[:value] }.sum.to_f / index_history[7..13].map { |data| data[:value] }.sum

      current_wday = resolution_date.wday

      target = index_history.find { |data| data[:date].cwday == current_wday }[:value] * ratio
      # rounding to nearest 0.5
      target_rounded = (target / 1e6 * 2).round(1) / 2.0
      target_str = "#{target_rounded}M"
      target_number = (target_rounded * 1e6).to_i.to_s(:delimited, delimiter: ",")

      {
        target: target_str,
        target_number: target_number,
      }
    when "binance_price"
      raise "symbol is required for binance prices template" if schedule_template_variables['symbol'].blank?
      raise "token is required for binance prices template" if schedule_template_variables['token'].blank?
      raise "decimals is required for binance prices template" if schedule_template_variables['decimals'].blank?

      price_events = BinanceApiService.get_price_events(schedule_template_variables['symbol'], '6h', 5)
      # fetching latest 5 data points and making a 50-20-10-10-10 average
      weights = [0.5, 0.2, 0.1, 0.1, 0.1].reverse
      target = price_events.each_with_index.map do |data, index|
        data[:close] * weights[index]
      end.sum

      decimals = (10 ** schedule_template_variables['decimals']).to_f

      target_rounded = (target / decimals * 2).round(1) / 2.0
      target_number = (target_rounded * decimals).to_i.to_s(:delimited, delimiter: ",")

      {
        target: target_number,
      }
    when "general"
      {}
    else
      raise "Unknown template type"
    end
  end
end
