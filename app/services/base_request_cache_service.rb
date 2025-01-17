class BaseRequestCacheService
  attr_reader :model, :model_type

  def initialize(model)
    @model = model
    @model_type = model.class.to_s.tableize
  end

  def get_markets(state: nil)
    data = Rails.cache.read(cache_key(state))

    decompress_data(data) if data
  end

  def refresh_markets
    markets = model.markets.includes(:outcomes).includes(:tournaments).published.to_a

    states = [nil, 'open', 'closed', 'resolved']
    states.each do |state|
      serialized_markets = ActiveModelSerializers::SerializableResource.new(
        state ? markets.select { |m| m.state == state } : markets,
      ).as_json
      Rails.cache.write(cache_key(state), compress_data(serialized_markets), expires_in: cache_ttl)
    end
  end

  private

  def cache_key(state)
    "base_requests:#{model_type}:#{model.id}:markets:#{state || 'all'}"
  end

  def cache_ttl
    (Rails.application.config_for(:cache).dig(:base_requests, model_type.to_sym) || 300).to_i.seconds
  end

  def compress_data(data)
    # compress the response to save cache space
    Zlib::Deflate.deflate(data.to_json, Zlib::BEST_COMPRESSION)
  end

  def decompress_data(data)
    Zlib::Inflate.inflate(data)
  end
end
