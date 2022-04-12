class TextRazorService
  def get_entities(text)
    return [] if Rails.application.config_for(:text_razor).api_key.blank?

    response = HTTP
      .headers(:'x-textrazor-key' => Rails.application.config_for(:text_razor).api_key)
      .post(text_razor_url, form: { extractors: 'entities', text: text, :'entities.dictionaries' => get_dictionaries })

    unless response.status.success?
      raise "TextRazorService #{response.status} :: #{response.body.to_s}"
    end

    entities = JSON.parse(response.body.to_s)['response']

    entities['entities'] || []
  end

  def get_dictionaries(refresh: false)
    return [] if Rails.application.config_for(:text_razor).api_key.blank?

    Rails.cache.fetch("text_razor:dictionaries", force: refresh) do
      response = HTTP
        .headers(:'x-textrazor-key' => Rails.application.config_for(:text_razor).api_key)
        .get(text_razor_url + 'entities/')

      unless response.status.success?
        raise "TextRazorService #{response.status} :: #{response.body.to_s}"
      end

      JSON.parse(response.body.to_s)['dictionaries'].map { |dictionary| dictionary['id'] }
    end
  end

  private

  def text_razor_url
    @_text_razor_url ||= 'https://api.textrazor.com/'
  end
end
