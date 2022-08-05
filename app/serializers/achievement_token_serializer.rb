class AchievementTokenSerializer < ActiveModel::Serializer
  attributes(
    :id,
    :name,
    :description,
    :token_count,
    :image,
  )
  attribute :get_attributes, key: :attributes

  def id
    # returning eth id in chain, not db market
    object.eth_id
  end

  def image
    object.image_url
  end

  def get_attributes
    # workaround due to ActiveModelSerializer attributes method name
    object.attributes
  end
end
