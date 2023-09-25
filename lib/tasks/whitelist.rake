namespace :whitelist do
  desc "cache whitelist addresses from spreadsheet to redis"
  task :cache, [:symbol] => :environment do |task, args|
    WhitelistService.new.refresh_item_list!
  end
end
