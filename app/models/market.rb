class Market < ApplicationRecord
  validates_presence_of :title, :category

  has_many :items, class_name: "MarketItem", dependent: :destroy

  validates :items, length: { minimum: 2, maximum: 2 } # currently supporting only binary markets
end
