class WhitelistService
  include ApplicationHelper

  attr_accessor :item

  def is_whitelisted?(item)
    item_is_email = is_email?(item)

    whitelist_row = item_list.find do |row|
      # if item is an email, stripping down dots and plus signs as well
      row.to_s.downcase == item.downcase ||
        (item_is_email && normalize_email(row.to_s) == normalize_email(item))
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

      spreadsheet.map { |row| row[0] }.uniq.compact
    end
  end
end
