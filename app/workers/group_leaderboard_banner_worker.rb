class GroupLeaderboardBannerWorker
  include Sidekiq::Worker

  def perform(group_leaderboard_id)
    group_leaderboard = GroupLeaderboard.find_by(id: group_leaderboard_id)
    return if group_leaderboard.blank?

    group_leaderboard.update_banner_image
  end
end
