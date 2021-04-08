class Market < ApplicationRecord
  validates_presence_of :title, :category

  has_many :items, class_name: "MarketItem", dependent: :destroy

  validates :items, length: { minimum: 2, maximum: 2 } # currently supporting only binary markets

  scope :published, -> { where('published_at > ', DateTime.now).where.not(market_id: nil) }

  def get_ethereum_data
    return nil if eth_market_id.blank?

    EthereumService.new.get_market(eth_market_id)
  end
end
