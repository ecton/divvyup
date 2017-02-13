
# frozen_string_literal: true
# Job is a base class that jobs must subclass
class DivvyUp::Job
  class << self
    attr_reader :queue

    def perform_async(*args)
      DivvyUp.service.enqueue job_class: self, args: args
    end
  end
end
