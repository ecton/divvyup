libdir = File.join(File.dirname(__FILE__), 'lib')
$LOAD_PATH.unshift(libdir)

require 'divvyup'

SemanticLogger.add_appender(io: $stdout, formatter: :color)
SemanticLogger.default_level = :trace
 
DivvyUp.redis = Redis.new(host: 'redis-1a.coreapps.xyz')


class TestWorker < DivvyUp::Job
  include DivvyUp::Utils

  @queue = :test

  def perform(message)
    log(:info, message)
  end
end