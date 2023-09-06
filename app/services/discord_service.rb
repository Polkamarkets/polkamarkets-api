class DiscordService
  def get_username(token:)

    response = HTTP.auth("Bearer #{token}").get('https://discord.com/api/users/@me')

    unless response.status.success?
      return nil
    end

    JSON.parse(response.body.to_s)['username']
  end

  def get_servers(token:)
    response = HTTP.auth("Bearer #{token}").get('https://discord.com/api/users/@me/guilds')

    unless response.status.success?
      return nil
    end

    # map response to return only the id and name of each server
    JSON.parse(response.body.to_s).map { |server| { id: server['id'], name: server['name'] } }
  end

  def revoke_token(token:)
    response = HTTP.post('https://discord.com/api/oauth2/token/revoke', :form => {
      :client_id => Rails.application.config_for(:discord).client_id,
      :client_secret => Rails.application.config_for(:discord).client_secret,
      :token => token
    })
  end
end
