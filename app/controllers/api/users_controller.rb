module Api
  class UsersController < BaseController
    before_action :authenticate_user!

    def update

      # create dictionary of params to update
      update_data = {
        'login_type' => params[:login_type],
        'avatar' => params[:avatar]
      }

      if current_user.wallet_address.nil?
        social_address = get_address_from_compressed_public_key(current_user.login_public_key)
        smart_account_address = get_smart_account_address_from_social_address(social_address)

        update_data['wallet_address'] = smart_account_address
      end

      if params[:login_type] == 'discord' && params[:oauth_access_token]
        # get username and servers from discord
        discord_service = DiscordService.new
        username = discord_service.get_username(token: params[:oauth_access_token])
        unless username.nil?
          update_data['username'] = username
        end

        servers = discord_service.get_servers(token: params[:oauth_access_token])
        unless servers.nil?
          update_data['discord_servers'] = servers
        end

        # revoke token to allow new login
        discord_service.revoke_token(token: params[:oauth_access_token])
      end

      current_user.update(update_data)

      render json: { update: 'ok' }, status: :ok
    end

    private

    def get_address_from_compressed_public_key(compressed_public_key)
      public_key = Secp256k1::PublicKey.from_data(Secp256k1::Util.hex_to_bin(compressed_public_key))

      keccak256 = Digest::Keccak.digest(public_key.uncompressed[1..-1], 256)

      '0x' + Secp256k1::Util.bin_to_hex(keccak256[-20..-1])
    end

    def get_smart_account_address_from_social_address(social_address)
      response = HTTP.get("https://sdk-backend.prod.biconomy.io/v1/smart-accounts/chainId/1/owner/#{social_address}")
      if response.code == 200
        JSON.parse(response.body.to_s)['data'][0]['smartAccountAddress']
      end
    end
  end
end
