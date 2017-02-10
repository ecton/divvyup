require 'redis'

class DivvyUp
  class << self
    attr_accessor :redis
    def redis
      @redis ||= Redis.new
    end

    attr_accessor :namespace
    def namespace
      @namespace ||= 'divvyup'
    end

    def service
      Service.new(redis: redis, namespace: namespace)
    end
  end
end

require 'divvyup/service'
require 'divvyup/worker'
require 'divvyup/job'