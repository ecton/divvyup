require File.expand_path('lib/divvyup/version')

Gem::Specification.new do |s|
  s.name        = 'divvyup'
  s.version     = DivvyUp::VERSION
  s.summary     = 'DivvyUp Worker Queue'
  s.description = 'A simple redis-based queue system designed for failure'
  s.authors     = ['Jonathan Johnson']
  s.email       = 'jon@nilobject.com'
  s.files       = `git ls-files`.split("\n")
  s.homepage    =
    'http://github.com/nilobject/divvyup'
  s.license       = 'MIT'

  s.require_path = 'lib'

  s.add_development_dependency 'bundler', '>= 1.0.0'
  s.add_dependency 'redis'
  s.add_dependency 'semantic_logger'
  s.add_dependency 'json'
end