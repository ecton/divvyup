# frozen_string_literal: true
require 'semantic_logger'

class DivvyUp
  # Utils defines base methods included in all divvyup core classes.
  module Utils
    def logger
      @logger ||= SemanticLogger[self.class.name]
    end

    def log(level, message, args = {})
      logger.send(level, message, args)
    end
  end
end
