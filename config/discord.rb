default: &default
  bot_token: <%= ENV['DISCORD_BOT_TOKEN'] %>

production:
  <<: *default

staging:
  <<: *default

development:
  <<: *default
