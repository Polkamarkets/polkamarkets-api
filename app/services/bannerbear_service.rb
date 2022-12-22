class BannerbearService
  include NetworkHelper

  def create_banner_image(market)
    modifications = {
      template: Rails.application.config_for(:bannerbear).template_id,
      modifications: [
        {
          name: "background_image",
          image_url: Rails.application.config_for(:bannerbear).categories.dig(market.category.to_sym, :background_image)
        },
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
          text: "#{market.category} / *#{market.subcategory}*",
          color: Rails.application.config_for(:bannerbear).categories.dig(market.category.to_sym, :category_color),
          color_2: Rails.application.config_for(:bannerbear).categories.dig(market.category.to_sym, :category_color_2),
        },
        {
          name: "chain_image",
          image_url: Rails.application.config_for(:ethereum)[:"network_#{market.network_id}"][:image_url]
        },
        {
          name: "chain_title",
          text: "available on *#{network_name(market.network_id)}*"
        },
      ],
      template_version: Rails.application.config_for(:bannerbear).template_version
    }

    create_image(modifications)
  end

  def create_achievement_token_image(achievement_token)
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

  def create_group_leaderboard_banner_image(group_leaderboard, token_ticker = 'POLK')
    modifications = {
      template: Rails.application.config_for(:bannerbear).group_leaderboards_template_id,
      modifications: [
        {
          name: "title",
          text: group_leaderboard.title
        },
      ],
      template_version: Rails.application.config_for(:bannerbear).group_leaderboards_template_version
    }

    users = group_leaderboard.leaderboard_users

    # fetching leaderboard top 5 users and filling up the template
    5.times do |i|
      user = users[i]
      modifications[:modifications] << {
        name: "contribution_#{i + 1}",
        text: user ? "*#{user[:address][0..3]}...#{user[:address][-4..-1]}*" : "**"
      }
      modifications[:modifications] << {
        name: "balance_#{i + 1}",
        text: user ? "*#{user[:balance].round(0)} $#{token_ticker}*" : "**"
      }
      modifications[:modifications] << {
        name: "rectangle_#{i + 1}",
        opacity: user ? 1 : 0
      }

      if i <= 2
        modifications[:modifications] << {
          name: "avatar_#{i + 1}",
          opacity: user ? 1 : 0
        }
      end
    end

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
