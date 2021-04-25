class WhitelistService
  attr_accessor :address

  def initialize(address)
    @address = address
  end

  def whitelisted_status
    whitelist_row = address_list.find { |row| row.to_s.downcase == address.downcase }

    {
      address: address,
      whitelisted: whitelist_row.present?,
    }
  end

  private

  def address_list
    Rails.cache.fetch("whitelist:addresses") do
      spreadsheet = GoogleSpreadsheetsService.new.fetch_spreadsheet(
        Config.whitelist.spreadsheet_id,
        Config.whitelist.spreadsheet_tab,
        Config.whitelist.spreadsheet_range,
      )

      # row 5 - has access boolean
      # row 4 - eth address
      spreadsheet.select { |row| row[5].to_s.downcase == "true" }.map { |row| row[4] }
    end
  end
end
