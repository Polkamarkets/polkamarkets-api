require 'discordrb'

class Discord::Bot
  def self.build
    bot = Discordrb::Bot.new(token: Config.discord.bot_token)
    new(bot: bot)
  end

  def initialize(bot:)
    @bot = bot
  end

  def start
    @bot.run
  end

  def send_message_to_channel(channel_id: message:)
    @bot.send_message(channel_id, message)
    @bot.stop
  end

end
