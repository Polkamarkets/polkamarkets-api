class BaseRequestCacheService
  attr_reader :model, :model_type

  def initialize(model)
    @model = model
    @model_type = model.class.to_s.tableize
  end

  def self.join_multiple_base_requests(data)
    "[" + data.select { |d| d.present? && d != '[]' }.map { |d| d[1..-2] }.join(",") + "]"
  end

  def get_markets(state: nil)
    data = Rails.cache.read(cache_key(state))

    decompress_data(data) if data
  end

  def refresh_markets
    markets = model.markets.includes(:outcomes).includes(:tournaments).published.to_a
    # sorting by featured + publish date
    markets.sort_by! { |market| market.featured ? -1 * market.featured_at.to_i : market.published_at.to_i }

    states = [nil, 'open', 'closed', 'resolved', 'featured']

    all_serialized_markets = ActiveModelSerializers::SerializableResource.new(markets).as_json

    states.each do |state|
      serialized_markets = all_serialized_markets.select do |market|
        next true if state.blank?

        if state == 'featured'
          market[:featured]
        else
          market[:state] == state
        end
      end
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
