module ApplicationHelper
  def polkamarkets_web_market_url(eth_market_id)
    "#{Config.polkamarkets.web_url}/markets/#{eth_market_id}"
  end
end
