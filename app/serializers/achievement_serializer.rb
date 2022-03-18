class AchievementSerializer < ActiveModel::Serializer
  attributes(
    :id,
    :network_id,
    :action,
    :occurrences,
    :image_url,
    :verified,
    :title,
    :description
  )

  def id
    # returning eth id in chain, not db market
    object.eth_id
  end
end
