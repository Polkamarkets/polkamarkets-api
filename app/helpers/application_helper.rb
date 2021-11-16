module ApplicationHelper
  def polkamarkets_web_market_url(eth_market_id)
    "#{Rails.application.config_for(:polkamarkets).web_url}/markets/#{eth_market_id}"
  end
end
