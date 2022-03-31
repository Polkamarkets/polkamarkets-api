class TextRazorService
  def get_entities(text)
    uri = 'https://api.textrazor.com/'

    return if Rails.application.config_for(:text_razor).api_key.blank?

    response = HTTP
      .headers(:'x-textrazor-key' => Rails.application.config_for(:text_razor).api_key)
      .post(uri, form: { extractors: 'entities', text: text })

    unless response.status.success?
      raise "TextRazorService #{response.status} :: #{response.body.to_s}"
    end

    entities = JSON.parse(response.body.to_s)['response']

    entities['entities'] || []
  end
end
