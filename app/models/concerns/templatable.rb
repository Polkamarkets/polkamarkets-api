module Templatable
  extend ActiveSupport::Concern

  included do
    def variables
      template.values.map { |value| field_variables(value) }.compact.flatten.uniq
    end

    def field_variables(value)
      # finding {{var_name}} in template values
      if value.is_a?(Array)
        value.map do |v|
          v.is_a?(Hash) ? v.values.to_s.scan(/{{(.*?)}}/).flatten.map(&:strip) : v.to_s.scan(/{{(.*?)}}/).flatten.map(&:strip)
        end
      else
        value.to_s.scan(/{{(.*?)}}/).flatten.map(&:strip)
      end
    end

    def template_field(key, variables)
      value = template.dig(*key)

      return value if field_variables(value).blank? || !value.is_a?(String)

      field_variables(value).each do |var|
        raise "Variable '#{var}' not found in template variables" unless variables.key?(var)
        # TODO: ignore spaces inside {{ }} if any
        value.gsub!("{{#{var}}}", variables[var].to_s)
      end

      value
    end
  end
end
