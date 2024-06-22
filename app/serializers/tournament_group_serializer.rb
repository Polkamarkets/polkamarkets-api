class TournamentGroupSerializer < BaseSerializer
  cache expires_in: 24.hours, except: [:redeem_code]

  attributes(
    :id,
    :slug,
    :title,
    :description,
    :short_description,
    :token,
    :created_at,
    :position,
    :users,
    :image_url,
    :banner_url,
    :metadata_url,
    :tags,
    :social_urls,
    :admins,
    :published,
    :website_url,
    :whitelabel,
    :onboarded,
    :advanced
  )

  attribute :redeem_code, if: :show_redeem_code?

  has_many :tournaments, serializer: TournamentSerializer, if: :show_tournaments?

  def show_tournaments?
    !!instance_options[:show_tournaments]
  end

  def show_redeem_code?
    !!instance_options[:show_redeem_code]
  end
end
