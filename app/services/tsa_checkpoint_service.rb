class TsaCheckpointService
  def get_history
    # fetching data from current and past year
    current_year = DateTime.now.year

    current_year_data = get_year_history
    previous_year_data = get_year_history(current_year - 1)

    current_year_data + previous_year_data.sort_by { |data| data[:date] }.reverse
  end

  def get_year_history(year = nil)
    # Fetch the Fear and Greed Index data from the API
    uri = "https://www.tsa.gov/travel/passenger-volumes"
    uri += "/#{year}" if year

    fetch_tsa_data(uri)
  end

  def fetch_tsa_data(uri)
    response = HTTP.get(uri)
    raise "TsaCheckpointService :: Error fetching data" unless response.status.success?

    # Parse the JSON response
    data = Nokogiri::HTML(response.body.to_s)

    data.search('table tbody tr').map do |row|
      date_str, value_str = row.css('td').map(&:text)
      # parsing date in format "MM/DD/YYYY"
      date = Date.strptime(date_str, '%m/%d/%Y')
      # stripping , and converting to float
      value = value_str.delete(',').to_i

      {
        date: date,
        value: value
      }
    end
  end
end
