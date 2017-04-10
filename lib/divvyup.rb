# frozen_string_literal: true
require 'redis'

# DivvyUp houses all DivvyUp functionality, and exposes simple singleton-style
# interactions for ease of use, although it is possible to instantiate
# DivvyUp classes without relying on the singleton Redis/Service instances.
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

    attr_accessor :on_error

    def service
      service = Service.new(redis: redis, namespace: namespace)
      service.on_error = @on_error
      service
    end
  end
end

require 'divvyup/service'
require 'divvyup/worker'
require 'divvyup/job'
