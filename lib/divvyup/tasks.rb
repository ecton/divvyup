# frozen_string_literal: true
# rubocop:disable Metrics/BlockLength
require 'divvyup'
namespace :divvyup do
  task :work do
    DivvyUp.namespace = ENV['NAMESPACE'] if ENV['NAMESPACE']
    DivvyUp.redis = Redis.new(host: ENV['REDIS']) if ENV['REDIS']
    worker = DivvyUp::Worker.new(queues: ENV['QUEUES'].split(','))
    worker.on_error = DivvyUp.on_error
    worker.work!
  end

  task :status do
    DivvyUp.namespace = ENV['NAMESPACE'] if ENV['NAMESPACE']
    DivvyUp.redis = Redis.new(host: ENV['REDIS']) if ENV['REDIS']

    puts 'Queues'
    DivvyUp.redis.smembers("#{DivvyUp.namespace}::queues").sort.each do |queue|
      puts "- #{queue}: #{DivvyUp.redis.llen("#{DivvyUp.namespace}::queue::#{queue}")}"
    end

    puts 'Workers'
    workers = DivvyUp.redis.hgetall("#{DivvyUp.namespace}::workers")
    workers.keys.sort.each do |worker_id|
      status = "- #{worker_id} "
      checkin_delta = Time.now.to_i - workers[worker_id].to_i
      status += '(stale) ' if checkin_delta > 45
      job = DivvyUp.redis.hgetall("#{DivvyUp.namespace}::worker::#{worker_id}::job")
      if job.count.positive?
        work = JSON.parse(job['work'])
        status += "#{work['queue']}: #{work['class']} since #{Time.at(job['started_at'].to_i).utc}"
      end
      puts status
    end
  end
end
