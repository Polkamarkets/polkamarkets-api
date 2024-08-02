class TournamentGroupSerializer < BaseSerializer
  cache expires_in: 24.hours, except: [:redeem_code]

  attributes(
    :id,
    :slug,
    :title,
    :network_id,
    :description,
    :short_description,
    :token,
    :token_controller_address,
    :created_at,
    :position,
    :rank_by,
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
    :advanced,
    :topics
  )

  attribute :redeem_code, if: :show_redeem_code?

  has_many :tournaments, serializer: TournamentSerializer, if: :show_tournaments?

  def show_tournaments?
    !!instance_options[:show_tournaments]
  end

  def show_redeem_code?
    !!instance_options[:show_redeem_code]
  end

  def users
    object.users_count
  end
end
