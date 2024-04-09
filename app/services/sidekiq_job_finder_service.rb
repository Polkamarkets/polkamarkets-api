class SidekiqJobFinderService
  def pending_job_running?(job_id)
    workers.any? do |_process_id, _thread_id, work|
      return true if work['payload']['jid'] == job_id
    end
  end

  def pending_job_running?(klass, args)
    workers.any? do |_process_id, _thread_id, work|
      return true if work['payload']['class'] == klass && work['payload']['args'] == args
    end
  end

  def workers
    workers = Sidekiq::Workers.new
  end
end
