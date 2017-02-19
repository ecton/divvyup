# frozen_string_literal: true
require 'divvyup'
namespace :divvyup do
  task :work do
    DivvyUp.redis = Redis.new(env['REDIS']) if ENV['REDIS']
    DivvyUp::Worker.new(queues: ENV['QUEUES'].split(',')).work!
  end
end
