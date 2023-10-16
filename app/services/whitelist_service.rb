class WhitelistService
  include ApplicationHelper

  attr_accessor :item

  def is_whitelisted?(item)
    return false unless is_email?(item)

    whitelist_row = item_list.find do |row|
      # if item is an email, stripping down dots and plus signs as well
      normalize_email(row[:email].to_s) == normalize_email(item)
    end

    whitelist_row.present?
  end

  def is_email?(item)
    item.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
  end

  def refresh_item_list!
    item_list(refresh: true)
  end

  def item_list(refresh: false)
    Rails.cache.fetch("whitelist:items", force: refresh) do
      spreadsheet = GoogleSpreadsheetsService.new.fetch_spreadsheet(
        Rails.application.config_for(:whitelist).spreadsheet_id,
        Rails.application.config_for(:whitelist).spreadsheet_tab,
        Rails.application.config_for(:whitelist).spreadsheet_range,
      )

      spreadsheet.map do |row|
        {
          username: row[0].to_s.gsub("*", ""),
          email: normalize_email(row[1].to_s),
          avatar: row[5].to_s
        }
      end
    end
  end
end
