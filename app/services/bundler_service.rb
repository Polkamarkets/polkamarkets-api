class BundlerService
  def initialize
    raise 'Bundler not configured' if bundler_url.blank? || bundler_entry_point.blank?
  end

  def process_user_operation(user_operation, network_id)
    uri = bundler_url + "/rpc?chainId=#{network_id}"
    body = {
      method: 'eth_sendUserOperation',
      params: [user_operation, bundler_entry_point]
    }

    puts body

    Sentry.with_scope do |scope|
      scope.set_tags(
        uri: uri,
        body: body
      )

      begin
        response = HTTP.post(uri, json: body)
        response_body = response.body.to_s

        unless response.status.success?
          scope.set_tags(
            status: response.status,
            error: response_body.to_s
          )
          raise "BundlerService :: Error"
        end

        JSON.parse(response_body.to_s)
      rescue => e
        scope.set_tags(
          error: e.message
        )
        raise "BundlerService :: Error"
      end
    end
  end

  private

  def bundler_url
    Rails.application.config_for(:ethereum).bundler_url
  end

  def bundler_entry_point
    Rails.application.config_for(:ethereum).bundler_entry_point
  end
end
