class BannerbearService
  def create_banner_image(market)
    modifications = {
      template: Rails.application.config_for(:bannerbear).template_id,
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
        },
        {
          name: "chain_image",
          image_url: Rails.application.config_for(:ethereum)[:"network_#{market.network_id}"][:image_url]
        },
      ],
      template_version: Rails.application.config_for(:bannerbear).template_version
    }

    create_image(modifications)
  end

  def create_achivement_token_image(achievement_token)
    modifications = {
      template: Rails.application.config_for(:bannerbear).achievements_template_id,
      modifications: [
        {
          name: "rank",
          text: "##{achievement_token.get_rank}"
        },
        {
          name: "background_image",
          image_url: achievement_token.achievement.image_url
        },
        {
          name: "chain_image",
          image_url: Rails.application.config_for(:ethereum)[:"network_#{achievement_token.network_id}"][:image_url]
        }
      ],
      template_version: Rails.application.config_for(:bannerbear).achievements_template_version
    }

    create_image(modifications)
  end

  def create_image(modifications)
    uri = bannerbear_url + 'images'

    return if modifications[:template].blank? || Rails.application.config_for(:bannerbear).api_key.blank?

    response = HTTP
      .auth("Bearer #{Rails.application.config_for(:bannerbear).api_key}")
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
