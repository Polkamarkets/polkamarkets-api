module Bepro
  class DisperseContractService < SmartContractService
    include BigNumberHelper
    include NetworkHelper

    def initialize(network_id: nil, api_url: nil, contract_address: nil)
      super(
        network_id: network_id,
        contract_name: "disperse",
        contract_address:
          contract_address ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :disperse_contract_address),
        api_url:
          api_url ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :bepro_api_url),
      )
    end

    # Distribute tokens to multiple recipients
    # @param token_address [String] The token contract address
    # @param recipients [Array<String>] Array of recipient addresses
    # @param amounts [Array<Float>] Array of amounts to distribute (in token units)
    def disperse_tokens(token_address, recipients, amounts)
      # Convert amounts to big numbers with 18 decimals
      amounts_big = amounts.map { |amount| from_float_to_big_number(amount, 18).to_s }

      execute(
        method: 'disperseToken',
        args: [
          token_address,
          recipients,
          amounts_big
        ]
      )
    end

    # Distribute ETH to multiple recipients
    # @param recipients [Array<String>] Array of recipient addresses
    # @param amounts [Array<Float>] Array of amounts to distribute (in ETH)
    def disperse_eth(recipients, amounts)
      # Convert amounts to big numbers with 18 decimals
      amounts_big = amounts.map { |amount| from_float_to_big_number(amount, 18).to_s }

      execute(
        method: 'disperseEther',
        args: [
          recipients,
          amounts_big
        ]
      )
    end

    # Get the total amount needed for distribution
    # @param amounts [Array<Float>] Array of amounts to distribute
    # @return [Float] Total amount needed
    def calculate_total_amount(amounts)
      amounts.sum
    end

    # Check if the contract has sufficient token balance for distribution
    # @param token_address [String] The token contract address
    # @param total_amount [Float] Total amount needed for distribution
    # @return [Boolean] True if sufficient balance, false otherwise
    def sufficient_token_balance?(token_address, total_amount)
      token_contract = Bepro::Erc20ContractService.new(
        network_id: network_id,
        contract_address: token_address
      )

      contract_balance = token_contract.balance_of(executor_address)
      contract_balance >= total_amount
    end

    # Check if the contract has sufficient ETH balance for distribution
    # @param total_amount [Float] Total amount needed for distribution
    # @return [Boolean] True if sufficient balance, false otherwise
    def sufficient_eth_balance?(total_amount)
      eth_balance = call(method: 'getBalance')
      from_big_number_to_float(eth_balance, 18) >= total_amount
    end
  end
end
