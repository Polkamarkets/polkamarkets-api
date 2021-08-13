class Erc20FaucetService
  include BigNumberHelper

  ERC20_AMOUNT = 500

  def transfer_or_ignore(user, address)
    # not allowing same user / address to request erc20 in a 24h period
    return false if user_has_received?(user) || user_has_received?(address)

    # not a valid eth address
    return false if !address.match(/0[x,X][a-fA-F0-9]{40}$/)

    erc20_service.transfer(address, ERC20_AMOUNT)

    set_user_received(address)
    set_user_received(user)

    true
  end

  def user_has_received?(user)
    Rails.cache.read("faucet:#{user.downcase}").present?
  end

  def set_user_received(user)
    Rails.cache.write("faucet:#{user.downcase}", true, expires_in: 24.hours)
  end

  private

  def erc20_service
    @_erc20_service ||= Ethereum::Erc20ContractService.new
  end
end
