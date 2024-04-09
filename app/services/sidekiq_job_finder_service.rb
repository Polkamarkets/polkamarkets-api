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

  def pending_job_queued?(job_id)
    queues.any? do |queue|
      queue.any? do |job|
        return true if job['jid'] == job_id
      end
    end
  end

  def pending_job_queued?(klass, args)
    queues.any? do |queue|
      queue.any? do |job|
        return true if job['class'] == klass && job['args'] == args
      end
    end
  end

  def pending_job?(klass, args)
    pending_job_running?(klass, args) || pending_job_queued?(klass, args)
  end

  private

  def workers
    workers = Sidekiq::Workers.new
  end

  def queues
    queues = Sidekiq::Queue.all
  end
end
