module Reportable
  extend ActiveSupport::Concern

  included do
    has_many :reports, as: :reportable, dependent: :destroy

    def content_title
      case self.class.to_s
      when 'Market', 'Tournament', 'TournamentGroup'
        title
      when 'Comment'
        body
      else
        raise 'Unknown class'
      end
    end

    def public_url
      # if market is already published on chain, then some fields can't be edited no more
      case self.class.to_s
      when 'Market'
        "#{Rails.application.config_for(:polkamarkets).web_url}/questions/#{slug}"
      when 'Comment'
        "#{Rails.application.config_for(:polkamarkets).web_url}/questions/#{market.slug}"
      when 'Tournament'
        "#{Rails.application.config_for(:polkamarkets).web_url}/contests/#{slug}"
      when 'TournamentGroup'
        "#{Rails.application.config_for(:polkamarkets).web_url}/#{slug}"
      else
        raise 'Unknown class'
      end
    end
  end
end
