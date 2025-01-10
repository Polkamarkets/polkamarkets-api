module Bepro
  class Erc20ContractService < SmartContractService
    include BigNumberHelper

    def initialize(network_id: nil, api_url: nil, contract_address: nil)
      super(
        network_id: network_id,
        contract_name: 'erc20',
        contract_address:
          contract_address ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :erc20_contract_address) ||
            Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :erc20_contract_address),
        api_url:
          api_url ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :bepro_api_url) ||
            Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :bepro_api_url),
      )
    end

    def balance_of(user)
      # if contract is not deployed, returning 0 as default
      return 0 if contract_address.blank?

      from_big_number_to_float(call(method: 'balanceOf', args: user), decimals)
    end

    def allowance(owner, spender)
      # if contract is not deployed, returning 0 as default
      return 0 if contract_address.blank?

      from_big_number_to_float(call(method: 'allowance', args: [owner, spender]), decimals)
    end

    def decimals
      @_decimals ||= call(method: 'decimals')
    end

    def token_info
      {
        name: name,
        address: contract_address,
        symbol: symbol,
        decimals: decimals,
      }
    end

    def mint_tokens(to:, amount:)
      execute(method: 'mint', args: [to, from_float_to_big_number(amount, decimals).to_s])
    end

    def approve(spender:, amount:)
      execute(method: 'approve', args: [spender, from_float_to_big_number(amount, decimals).to_s])
    end

    def transfer(to:, amount:)
      execute(method: 'transfer', args: [to, from_float_to_big_number(amount, decimals).to_s])
    end

    def name
      Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :tokens, contract_address, :name) ||
        call(method: 'name')
    end

    def symbol
      Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :tokens, contract_address, :symbol) ||
        call(method: 'symbol')
    end

    def transfer_events(from: nil, to: nil, from_block: nil, to_block: nil)
      events = get_events(
        event_name: 'Transfer',
        filter: {
          from: from,
          to: to
        },
        from_block: from_block,
        to_block: to_block
      )

      events.map do |event|
        {
          from: event['returnValues']['from'],
          to: event['returnValues']['to'],
          value: from_big_number_to_float(event['returnValues']['value'], decimals),
          block_number: event['blockNumber']
        }
      end
    end

    def burn_events(from: nil, from_block: nil, to_block: nil)
      transfer_events(
        from: from,
        to: '0x0000000000000000000000000000000000000000',
        from_block: from_block,
        to_block: to_block
      )
    end

    def mint_events(to: nil, from_block: nil, to_block: nil)
      transfer_events(
        from: '0x0000000000000000000000000000000000000000',
        to: to,
        from_block: from_block,
        to_block: to_block
      )
    end
  end
end
