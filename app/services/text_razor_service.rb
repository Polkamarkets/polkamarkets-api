class TextRazorService
  def get_entities(text)
    return [] if Rails.application.config_for(:text_razor).api_key.blank?

    response = HTTP
      .headers(:'x-textrazor-key' => Rails.application.config_for(:text_razor).api_key)
      .post(text_razor_url, form: { extractors: 'entities', text: text })

    unless response.status.success?
      raise "TextRazorService #{response.status} :: #{response.body.to_s}"
    end

    entities = JSON.parse(response.body.to_s)['response']

    entities['entities'] || []
  end

  private

  def text_razor_url
    @_text_razor_url ||= 'https://api.textrazor.com/'
  end
end
