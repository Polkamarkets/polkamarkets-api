class NewsAPIService
  VERSION = 'v2'.freeze
  BASE_URL = "https://newsapi.org/#{VERSION}/".freeze

  def initialize
    @api_key = Rails.application.config_for(:newsapi).api_key
  end

  def get_latest_news
    [
      {
        title: "Canadian trucker protesters have bitcoin donations seized",
        description: "The Canadian truckers protesting vaccine mandates had their donations seized, even if the contributions were made in Bitcoin, reported Vice's Motherboard on Tuesday. While the overwhelming majority (over 90 percent) of truckers in Canada have been vaccinated,…",
        url: "https://www.rawstory.com/canadian-trucker-protest-bitcoin-taken/",
        image_url: "https://www.rawstory.com/media-library/canada-police-ready-to-move-in-to-clear-trucker-led-protests.jpg?id=29368068&width=1200&coordinates=0%2C36%2C0%2C36&height=600",
  
      }
    ]
  end
end