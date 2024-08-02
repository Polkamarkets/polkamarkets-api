
class ParticleService
  attr_accessor :api_url, :project_id, :client_key

  def initialize
    @api_url = Rails.application.config_for(:particle).api_url
    @project_id = Rails.application.config_for(:particle).project_id
    @client_key = Rails.application.config_for(:particle).client_key
  end

  def get_smart_account_addres(address:, chain_id: 100)
      uri = api_url + "/evm-chain"

      body = {
        jsonrpc: "2.0",
        id: SecureRandom.uuid,
        chainId: chain_id,
        method: "particle_aa_getSmartAccount",
        params: [
          {
            name: "SIMPLE",
            version: "1.0.0",
            ownerAddress: address
          }
        ]
      }

      Sentry.with_scope do |scope|
        scope.set_tags(
          uri: uri
        )

        begin
          response = HTTP.basic_auth(user: project_id, pass: client_key)
               .post(uri, json: body)
          response_body = response.body.to_s

          unless response.status.success? && !response_body.include?('server unavailable')
            scope.set_tags(
              status: response.status,
              error: response_body.to_s
            )
            raise "ParticleService :: Get Smart Account Address Error"
          end

          JSON.parse(response_body.to_s)["result"][0]["smartAccountAddress"]
        rescue => e
          scope.set_tags(
            error: e.message
          )
          raise "ParticleService :: Get Smart Account Address Error"
        end
      end
    end
end
