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
      args: args,
      queue: job_class.queue
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
    reclaim_stuck_work(worker)
    retrieve_new_work(worker)
  end

  private

  def reclaim_stuck_work(_worker)
    checkin_threshold = Time.now.to_i - 30 * 10
    @redis.hgetall("#{@namespace}::workers").each_pair do |worker_id, last_checkin|
      next if last_checkin.to_i > checkin_threshold

      log(:trace, 'Reaping worker', id: worker_id)
      reap_worker(worker_id)
    end
  end

  def reap_worker(worker_id)
    job = @redis.hget("#{@namespace}::worker::#{worker_id}::job", 'work')
    if job
      job = JSON.parse(job)
      log(:trace, 'Requeuing reaped work', id: worker_id, job: job)
      @redis.lpush("#{@namespace}::queue::#{job['queue']}", job.to_json)
    end
    @redis.del("#{@namespace}::worker::#{worker_id}::job")
    @redis.del("#{@namespace}::worker::#{worker_id}")
    @redis.hdel("#{@namespace}::workers", worker_id)
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
