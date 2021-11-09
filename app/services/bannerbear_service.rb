class BannerbearService
  def create_banner_image(market)
    uri = bannerbear_url + 'images'

    modifications = {
      template: Config.bannerbear.template_id,
      modifications: [
        {
          name: "title",
          text: market.title
        },
        {
          name: "outcome_1",
          text: market.outcomes[0].title
        },
        {
          name: "outcome_2",
          text: market.outcomes[1].title
        },
        {
          name: "image",
          image_url: market.image_url
        },
        {
          name: "category",
          text: "#{market.category} / *#{market.subcategory}*"
        }
      ]
    }

    response = HTTP
      .auth("Bearer #{Config.bannerbear.api_key}")
      .post(uri, json: modifications)

    unless response.status.success?
      raise "BannerbearService #{response.status} :: #{response.body.to_s}"
    end

    JSON.parse(response.body.to_s)["image_url"]
  end

  def bannerbear_url
    @_bannerbear_url ||= 'https://sync.api.bannerbear.com/v2/'
  end
end
