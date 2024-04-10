class EthQuery < ApplicationRecord
  validates_presence_of :contract_name, :network_id, :event, :contract_address, :api_url
  validates_uniqueness_of :filter, scope: %i[network_id contract_name event contract_address api_url]

  has_and_belongs_to_many :eth_events

  def reindex(force: false)
    # only enqueue backfill job if no same current job is running
    if force || !pending_index_running?
      EthEventsWorker.perform_async(*worker_args)
    end
  end

  def pending_index_running?
    SidekiqJobFinderService.new.pending_job?('EthEventsWorker', worker_args)
  end

  private

  def worker_args
    [
      network_id,
      contract_name,
      contract_address,
      api_url,
      event,
      JSON.parse(filter).deep_stringify_keys
    ]
  end
end
