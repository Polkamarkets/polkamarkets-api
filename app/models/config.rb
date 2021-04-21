# typed: false
require "erb"
require "json"

# simple config module to avoid need of creating initializer for every new yml config file
module Config
  extend self

  class Error < StandardError; end

  class Config < Struct
    PLACEHOLDER ||= "placeholder".freeze

    def key?(key)
      members.include?(key.to_sym)
    end

    alias_method :has_key?, :key?

    def fetch(key, default = nil)
      key?(key) || default.nil? ? self[key] : default
    end

    def [](key)
      if ::Config.placeholder_mode?
        public_send(key)
      else
        super
      end
    end

    def method_missing(name, *_args)
      if ::Config.placeholder_mode?
        self.class::PLACEHOLDER
      else
        super
      end
    end
  end

  ENV_PREFIX ||= "CONFIG_".freeze

  # in placeholder mode any non-existent configuration query will just return placeholder string
  # this can be useful when you need working configuration but you don't really care if it's correct
  def enable_placeholder_mode
    @placeholder_mode = true
  end

  def placeholder_mode?
    !!@placeholder_mode
  end

  def defined?(name)
    env_config_defined?(name) || file_config_defined?(name)
  end

  def file_config_defined?(name)
    config_filepath = config_file_path(name)
    File.exists?(config_filepath) && load_config_hash_from_file(name).any?
  end

  def env_config_defined?(name)
    prefix = "#{self::ENV_PREFIX}#{name.downcase}_".downcase
    !!ENV["#{self::ENV_PREFIX}#{name.upcase}"] || ENV.any? { |k, _| k.downcase.start_with?(prefix) }
  end

  def method_missing(name)
    load_config(name)
  rescue Error
    raise unless placeholder_mode?
    Config.new(nil).new
  end

  def load_config(name)
    config_hash = env_config_defined?(name) ? load_config_hash_from_env(name) : load_config_hash_from_file(name)

    raise Error.new("Config '#{name}' has no entries for #{Rails.env} environment") if config_hash.size.zero?

    config_class = Config.new(*config_hash.keys.map(&:to_sym))
    config = config_class.new(*config_hash.values)

    define_method(name) { config } # define method for faster access next time

    config
  end

  def load_config_hash_from_file(name)
    config_filepath = config_file_path(name)

    raise Error.new("#{config_filepath} doesn't exist") unless File.exists?(config_filepath)

    config_string = File.read(config_filepath)
    config_interpolated = ERB.new(config_string).result(binding).strip
    YAML.load(config_interpolated)[Rails.env] || {}
  end

  def load_config_hash_from_env(name)
    root_env_var = "#{self::ENV_PREFIX}#{name.upcase}"
    prefix = "#{self::ENV_PREFIX}#{name.upcase}_"

    base =
      if (root_value = ENV[root_env_var])
        JSON.parse(root_value)
      else
        {}
      end

    base.merge(
      ENV
        .select { |k, _| k.start_with?(prefix) }
        .map do |k, v|
          v = ERB.new(v).result(binding).strip
          [
            k.downcase[(self::ENV_PREFIX.length + name.length + 1)..-1], # downcase and remove prefix
            case v
            when /\A[{\[].*?[}\]]\z/m then JSON.parse(v) # parse json if it's json
            when "true" then true
            when "false" then false
            else v
            end,
          ]
        end
        .to_h
    )
  end

  def config_file_path(name)
    Rails.root.join("config/#{name}.yml")
  end
end
