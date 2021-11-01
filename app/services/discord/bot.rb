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
end
