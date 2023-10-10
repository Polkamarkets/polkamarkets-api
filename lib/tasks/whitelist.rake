namespace :whitelist do
  desc "cache whitelist addresses from spreadsheet to redis"
  task :cache, [:symbol] => :environment do |task, args|
    whitelist = WhitelistService.new.refresh_item_list!
    whitelist.each do |row|
      user = User.find_or_create_by(email: row[:email])
      user.update(
        {
          username: row[:username],
          avatar: row[:avatar]
        }.compact
      )
    end
  end
end
