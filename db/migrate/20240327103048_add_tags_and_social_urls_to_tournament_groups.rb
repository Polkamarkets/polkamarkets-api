class AddTagsAndSocialUrlsToTournamentGroups < ActiveRecord::Migration[6.0]
  def change
    add_column :tournament_groups, :tags, :jsonb, default: []
    add_column :tournament_groups, :social_urls, :jsonb, default: {}
  end
end
