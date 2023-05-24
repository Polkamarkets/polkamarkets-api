module ApplicationHelper
  def eth_address_valid?(eth_address)
    !!eth_address.match(/0[x,X][a-fA-F0-9]{40}$/)
  end
end
