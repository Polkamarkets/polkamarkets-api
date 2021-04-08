class Market < ApplicationRecord
  validates_presence_of :title, :category

  has_many :outcomes, class_name: "MarketOutcome", dependent: :destroy

  validates :outcomes, length: { minimum: 2, maximum: 2 } # currently supporting only binary markets

  scope :published, -> { where('published_at < ?', DateTime.now).where.not(eth_market_id: nil) }
  scope :open, -> { published.where('expires_at > ?', DateTime.now) }
  scope :resolved, -> { published.where('expires_at < ?', DateTime.now) }

  def get_ethereum_data
    return nil if eth_market_id.blank?

    EthereumService.new.get_market(eth_market_id)
  end
end
