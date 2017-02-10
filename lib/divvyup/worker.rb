require 'divvyup/utils'

class DivvyUp::Worker
  include DivvyUp::Utils
  def initialize(queues:, service: nil)
    @queues = queues
    @service = service || DivvyUp.service
    @worker_id = "#{Socket.gethostname}:#{Process.pid}"
  end

  attr_reader :queues, :service, :worker_id

  def work!
    background_check_in
    while true
      begin
        retrieve_and_execute_work
      #rescue => ex
      #  log(:error,
      #    'Error while listening for work',
      #    exception: ex)
      #  sleep 5
      end
    end
  end

private
  def background_check_in
    Thread.new {
      while true
        @service.worker_check_in(self) rescue nil
        sleep 30
      end
    }
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
    end
  end
end