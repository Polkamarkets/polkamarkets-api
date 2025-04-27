class MarketTemplate < ApplicationRecord
  validate :template_validation

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
end
