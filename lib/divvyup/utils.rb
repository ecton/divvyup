require 'semantic_logger'

class DivvyUp
  module Utils
    def logger
      @logger ||= SemanticLogger[self.class.name]
    end


    def log(level, message, args = {})
      logger.send(level, message, args)
    end
  end
end