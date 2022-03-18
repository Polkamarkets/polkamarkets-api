class AchievementTokenImageWorker
  include Sidekiq::Worker

  def perform(achievement_token_id)
    token = AchievementToken.find_by(id: achievement_token_id)
    return if token.blank?

    token.update_image
  end
end
