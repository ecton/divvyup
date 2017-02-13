# frozen_string_literal: true
require 'divvyup/utils'

# Worker defines the logic of how work is processed
class DivvyUp::Worker
  include DivvyUp::Utils
  def initialize(queues:, service: nil)
    @queues = queues
    @service = service || DivvyUp.service
    @worker_id = "#{Socket.gethostname}:#{Process.pid}"
  end

  attr_reader :queues, :service, :worker_id
  attr_accessor :on_error

  attr_writer :checkin_interval
  def checkin_interval
    @checkin_interval || 30
  end

  attr_writer :delay_after_internal_error
  def delay_after_internal_error
    @delay_after_internal_error || 5
  end

  def work!(forever = true)
    background_check_in
    loop do
      begin
        retrieve_and_execute_work
      rescue => ex
        log(:error,
            'Error while listening for work',
            exception: ex.message,
            backtrace: ex.backtrace)
        sleep delay_after_internal_error
      end
      break unless forever
    end
  end

  private

  def background_check_in
    @background_thread ||= Thread.new do
      loop do
        begin
          @service.worker_check_in(self)
        rescue
          nil
        end
        sleep checkin_interval
      end
    end
  end

  def retrieve_and_execute_work
    work = @service.work_retrieve(self)
    if work
      log(:info, 'Received work', work: work)
      execute_work work
    else
      log(:trace, 'No work found')
      sleep 5
    end
  end

  def execute_work(work)
    @service.work_starting(self, work)
    begin
      worker_class = Object.const_get(work['class'])
      result = worker_class.new.perform(*work['args'])
      @service.work_finished(self, work)
      result
    rescue => exc
      @service.work_failed(self, work, exc)
      on_error&.call(exc)
    end
  end
end
