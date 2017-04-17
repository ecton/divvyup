# frozen_string_literal: true
require 'fakeredis'
require 'divvyup'

DivvyUp.redis = FakeRedis::Redis.new
DivvyUp.namespace = 'testing'
SemanticLogger.default_level = :trace if ENV['DEBUG']
SemanticLogger.add_appender(io: $stdout, formatter: :color) if ENV['DEBUG']

# In general I support smaller test methods covering individual chunks of functionality
# However, I threw this project together rather quickly, and originally wasn't going to
# do testing outide of a "harness" file. I then changed my mind, but am in a rush
# so I'm creating a integration-style test that does entire flows, aiming to get the main
# functionality over test.
RSpec.describe DivvyUp do
  context 'integration test' do
    class RspecJob < DivvyUp::Job
      @queue = 'test'

      class << self
        def count(command)
          @counters ||= {}
          @counters[command] = @counters[command].to_i + 1
        end

        attr_reader :counters
      end

      def perform(command)
        self.class.count(command)
        raise ArgumentError if command == 'fail'
      end
    end

    it 'works' do
      worker = DivvyUp::Worker.new(queues: ['test'])
      worker.on_error = lambda do |exc|
        @worker_exception = exc
      end
      worker.checkin_interval = 1
      worker.delay_after_internal_error = 0

      # Verify simple test passes
      RspecJob.perform_async 'pass'
      worker.work!(false)
      expect(RspecJob.counters).to_not be_nil
      expect(RspecJob.counters['pass']).to eq(1)

      # Verify simple exceptions fail as expected
      RspecJob.perform_async 'fail'
      worker.work!(false)
      expect(RspecJob.counters['fail']).to eq(1)
      expect(@worker_exception).to be_a(ArgumentError)

      # Verify exceptions don't propogate upwards
      worker.on_error = lambda do |exc|
        raise exc
      end
      RspecJob.perform_async 'fail'
      expect { worker.work!(false) }.to_not raise_error

      # Test that no work causes no errors
      worker.work!(false)
    end

    it "background checkin doesn't break with bad service" do
      service = double('service')
      allow(service).to receive(:worker_check_in).and_raise(ArgumentError)
      allow(service).to receive(:work_retrieve)
      worker = DivvyUp::Worker.new(service: service, queues: ['test'])
      expect(service).to receive(:worker_check_in)
      worker.work!(false)
    end

    it 'stuck work is reclaimed' do
      DivvyUp.redis.hset('testing::workers', 'testworker1', 0)
      DivvyUp.redis.hset('testing::worker::testworker1', 'queues', ['test'].to_json)
      DivvyUp.redis.hset('testing::worker::testworker1::job', 'started_at', Time.now.to_i)
      DivvyUp.redis.hset('testing::worker::testworker1::job', 'work', {
        class: 'RspecJob',
        args: ['reclaimed'],
        queue: 'test'
      }.to_json)

      worker = DivvyUp::Worker.new(queues: ['test'])
      worker.checkin_interval = 1
      worker.delay_after_internal_error = 0

      # Verify simple test passes
      worker.work!(false)
      expect(RspecJob.counters).to_not be_nil
      expect(RspecJob.counters['reclaimed']).to eq(1)
    end
  end
end
