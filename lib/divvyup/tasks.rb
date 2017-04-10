# frozen_string_literal: true
require 'divvyup'
namespace :divvyup do
  task :work do
    DivvyUp.redis = Redis.new(env['REDIS']) if ENV['REDIS']
    worker = DivvyUp::Worker.new(queues: ENV['QUEUES'].split(','))
    worker.on_error = DivvyUp.on_error
    worker.work!
  end
end
