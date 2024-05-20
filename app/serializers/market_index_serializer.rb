class MarketIndexSerializer < MarketSerializer
  cache expires_in: 24.hours, except: [:liked, :comments]

  has_many :outcomes, class_name: "MarketOutcome", serializer: MarketOutcomeIndexSerializer

  def news
    # not displaying news for index view
    []
  end
end
