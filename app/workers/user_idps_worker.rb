class UserIdpsWorker
  include Sidekiq::Worker

  def perform(user_id)
    user = User.find_by(id: user_id)
    return if user.blank? || user.login_public_key.blank?

    privy_service = PrivyService.new

    # finding privy user by embedded wallet address
    users_data = privy_service.search_users_by_wallet_address(user.login_public_key)

    return if users_data['data'].blank?

    user_data = users_data['data'].first

    # creating user_idp for the user
    user.update(idp: 'privy', idp_uid: user_data['id'])
    user_data['linked_accounts'].each do |linked_account|
      idp_uid = privy_service.uid_from_linked_account_data(linked_account)
      user_idp = user.user_idps.find_or_initialize_by(provider: linked_account['type'], uid: idp_uid)
      user_idp.data = linked_account
      user_idp.save!
    end
  end
end
