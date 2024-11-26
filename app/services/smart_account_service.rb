class SmartAccountService

  def get_admin_account(network_id, wallet_address)
    begin
      simple_account_service = Bepro::SimpleAccountContractService.new(:network_id => network_id, :contract_address => wallet_address)
      return simple_account_service.get_owner()
    rescue
      begin
        account_core_service = Bepro::AccountCoreContractService.new(:network_id => network_id, :contract_address => wallet_address)
        admins = account_core_service.get_admins()
        return admins.first unless admins.empty?
      rescue
        return wallet_address
      end
    end
  end

end
