class TournamentGroupSerializer < BaseSerializer
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
    :tags,
    :social_urls,
    :admins,
    :published,
    :website_url,
    :whitelabel,
    :onboarded
  )

  has_many :tournaments, serializer: TournamentSerializer, if: :show_tournaments?

  def show_tournaments?
    !!instance_options[:show_tournaments]
  end
end
