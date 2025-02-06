
require "google/apis/sheets_v4"
require "googleauth"
require "googleauth/stores/file_token_store"

class GoogleSpreadsheetsService
  attr_accessor :service

  OOB_URI             = "urn:ietf:wg:oauth:2.0:oob".freeze
  APPLICATION_NAME    = "Google Sheets API Ruby Quickstart".freeze
  CREDENTIALS_PATH    = "tmp/google_credentials.json".freeze
  SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS_READONLY

  def initialize
    @service = Google::Apis::SheetsV4::SheetsService.new
    @service.client_options.application_name = APPLICATION_NAME
    # creating tmp file with credentials from env
    file = File.open(CREDENTIALS_PATH, "w") do |f|
      f.write Rails.application.config_for(:google).sheets_token.to_json
    end

    @service.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: File.open(CREDENTIALS_PATH),
      scope: Google::Apis::SheetsV4::AUTH_SPREADSHEETS
    )
  end

  def fetch_spreadsheet(spreadsheet_id, spreadsheet_tab, range)
    range = "#{spreadsheet_tab}!#{range}"
    response = service.get_spreadsheet_values spreadsheet_id, range
    response.values
  end

  def write_spreadsheet(spreadsheet_id, spreadsheet_tab, range, values)
    range = "#{spreadsheet_tab}!#{range}"
    value_range = Google::Apis::SheetsV4::ValueRange.new(values: values)
    service.update_spreadsheet_value(spreadsheet_id, range, value_range, value_input_option: "RAW")
  end
end
