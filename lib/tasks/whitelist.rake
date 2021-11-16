namespace :whitelist do
  desc "cache whitelist addresses from spreadsheet to redis"
  task :cache, [:symbol] => :environment do |task, args|
    spreadsheet = GoogleSpreadsheetsService.new.fetch_spreadsheet(
      Rails.application.config_for(:whitelist).spreadsheet_id,
      Rails.application.config_for(:whitelist).spreadsheet_tab,
      Rails.application.config_for(:whitelist).spreadsheet_range,
    )

    # row 5 - has access boolean
    # row 4 - eth address
    whitelist_addresses = spreadsheet.select { |row| row[5].to_s.downcase == "true" }.map { |row| row[4] }

    Rails.cache.write("whitelist:addresses", whitelist_addresses)
  end
end
