class GnewsService
  def get_latest_news(keywords)
    return [] if Rails.application.config_for(:news).gnews_api_key.blank?

    q = keywords.map { |keyword| "\"#{keyword}\""}.join(' OR ')

    uri = URI::Parser.new.escape("#{gnews_url}?q=#{q}&token=#{Rails.application.config_for(:news).gnews_api_key}&lang=en&max=100")

    response = HTTP.get(uri)

    unless response.status.success?
      raise "GnewsService #{response.status} :: #{response.body.to_s}"
    end

    articles = JSON.parse(response.body.to_s)['articles']
    # filtering repeated articles
    articles.uniq! { |article| article['title'] }

    articles[0..9].map do |article|
      {
        source: article['source']['name'],
        title: article['title'],
        description: article['description'],
        url: article['url'],
        image_url: article['image']
      }
    end
  end

  private

  def gnews_url
    @_gnews_url ||= 'https://gnews.io/api/v4/search'
  end
end
