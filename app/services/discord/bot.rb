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
    @bot.run true
  end

  def stop
    @bot.stop
  end

  def send_message_to_channel(message:)
    @bot.send_message(Config.discord.channel_id, message)
  end

end
