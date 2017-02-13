# frozen_string_literal: true
require 'divvyup/utils'
require 'json'

# Service is responsible for abstracting all of the redis interactions.
class DivvyUp::Service
  include DivvyUp::Utils

  def initialize(redis: nil, namespace: nil)
    @redis = redis || DivvyUp.redis || Redis.new
    @namespace = namespace || DivvyUp.namespace
  end

  def enqueue(job_class:, args: [])
    log(:trace, 'Enqueuing work', queue: job_class.queue, namespace: @namespace, job_class: job_class, args: args)
    @redis.lpush("#{@namespace}::queue::#{job_class.queue}", {
      class: job_class.name,
      args: args
    }.to_json)
  end

  def worker_check_in(worker)
    @redis.hset("#{@namespace}::workers", worker.worker_id, Time.now.to_i)
    @redis.hset("#{@namespace}::worker::#{worker.worker_id}", 'queues', worker.queues.to_json)
  end

  def work_starting(worker, work)
    @redis.hset("#{@namespace}::worker::#{worker.worker_id}::job", 'started_at', Time.now.to_i)
    @redis.hset("#{@namespace}::worker::#{worker.worker_id}::job", 'work', work.to_json)
  end

  def work_finished(worker, _work)
    @redis.del "#{@namespace}::worker::#{worker.worker_id}::job"
  end

  def work_failed(worker, work, exc)
    @redis.lpush("#{@namespace}::failed", {
      work: work,
      worker: worker.worker_id,
      message: exc.message,
      backtrace: exc.backtrace
    }.to_json)
    log(:error, 'Work failed', work: work, exception: exc)
  end

  def work_retrieve(worker)
    reclaim_stuck_work(worker) || retrieve_new_work(worker)
  end

  private

  def reclaim_stuck_work(_worker)
    # TODO: We need to look for workers that haven't checked in recently.
    # If we find any, we will remove them, but first we'll see if they were
    # in the middle of a job. If they were, we will re-queue it first.
    nil
  end

  def retrieve_new_work(worker)
    worker.queues.each do |queue|
      log(:trace, 'Checking Queue for Work', queue: queue, namespace: @namespace)
      work = @redis.rpop("#{@namespace}::queue::#{queue}")
      return JSON.parse(work) if work
    end
    nil
  end
end
