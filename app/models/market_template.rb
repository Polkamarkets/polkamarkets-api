class MarketTemplate < ApplicationRecord
  validate :template_validation
  validates :template_type, presence: true

  enum template_type: {
    fear_and_greed: 0,
    tsa_checkpoint: 1,
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

  def variables
    template.values.map { |value| field_variables(value) }.compact.flatten.uniq
  end

  def field_variables(value)
    # finding {{var_name}} in template values
    if value.is_a?(Array)
      value.map { |v| v.values.to_s.scan(/{{(.*?)}}/).flatten.map(&:strip) }.flatten
    else
      value.to_s.scan(/{{(.*?)}}/).flatten.map(&:strip)
    end
  end

  def template_field(key, variables)
    value = template.dig(*key)

    return value if field_variables(value).blank?

    field_variables(value).each do |var|
      raise "Variable '#{var}' not found in template variables" unless variables.key?(var)
      # TODO: ignore spaces inside {{ }} if any
      value.gsub!("{{#{var}}}", variables[var].to_s)
    end

    value
  end

  # TODO: move to separate services per template type
  def template_variables
    case template_type
    when "fear_and_greed"
      index_history = FearAndGreedService.get_index_history(3).map { |data| data[:value] }
      # fetching latest 3 days data and making a 70-20-10 average
      target = index_history.each_with_index.map { |value, index| value * (index == 0 ? 0.7 : index == 1 ? 0.2 : 0.1) }.sum.round
      now = DateTime.now.utc
      tomorrow = now + 1.day

      {
        close_date: now.strftime("%B #{now.day}, %Y"),
        resolution_date: tomorrow.strftime("%B #{tomorrow.day}, %Y"),
        resolution_date_short: tomorrow.strftime("%B #{tomorrow.day}"),
        target: target,
      }
    when "tsa_checkpoint"
      index_history = TsaCheckpointService.new.get_history
      # fetching latest 7 days, comparing with 7 days before and calculating ratio
      ratio = index_history.first(7).map { |data| data[:value] }.sum.to_f / index_history[7..13].map { |data| data[:value] }.sum

      now = DateTime.now.utc
      tomorrow = now + 1.day
      current_wday = now.wday

      target = index_history.find { |data| data[:date].cwday == current_wday }[:value] * ratio
      # rounding to nearest 0.5
      target_rounded = (target / 1e6 * 2).round(1) / 2.0
      target_str = "#{target_rounded}M"
      target_number = (target_rounded * 1e6).to_i.to_s(:delimited, delimiter: ",")

      {
        close_date: tomorrow.strftime("%B #{now.day}, %Y"),
        resolution_date: now.strftime("%B #{now.day}, %Y"),
        resolution_date_short: now.strftime("%B #{now.day}"),
        target: target_str,
        target_number: target_number,
      }
    else
      raise "Unknown template type"
    end
  end

  def template_expires_at
    case template_type
    when "fear_and_greed"
      DateTime.now.utc.beginning_of_day + 1.day - 1.minute
    when "tsa_checkpoint"
      DateTime.now.utc.beginning_of_day + 1.day + 11.hours
    else
      raise "Unknown template type"
    end
  end
end
