# -*- Ruby -*-
# -*- encoding: utf-8 -*-
require 'rake'
require 'rubygems' unless 
  Object.const_defined?(:Gem)
require File.dirname(__FILE__) + "/lib/set_trace" 

FILES = FileList[
  'README',
  'ChangeLog',
  'LICENSE',
  'NEWS',
  'Rakefile',
  'THANKS',
  'lib/*',
  'processor/**/*.rb',
  'test/**/*.rb',
]                        

Gem::Specification.new do |spec|
  spec.add_dependency('rbx-require-relative')
  spec.authors      = ['R. Bernstein']
  spec.date         = Time.now
  spec.description = <<-EOF
Emulates Ruby set_trace_func in Rubinus and contains related step-tracing 
features.
EOF
  ## spec.add_dependency('diff-lcs') # For testing only
  spec.author       = 'R. Bernstein'
  spec.email        = 'rockyb@rubyforge.net'
  spec.files        = FILES.to_a  
  spec.has_rdoc     = true
  spec.homepage     = 'http://wiki.github.com/rocky/rbx-tracer'
  spec.name         = 'rbx-tracer'
  spec.license      = 'MIT'
  spec.platform     = Gem::Platform::new ['universal', 'rubinius', '1.2']
  spec.require_path = 'lib'
  spec.required_ruby_version = '~> 1.8.7'
  spec.summary      = 'set_trace_func Rubinius 1.2 and above'
  spec.version      = Rubinius::SetTrace::VERSION

  # Make the readme file the start page for the generated html
  ## spec.rdoc_options += %w(--main README)
  spec.rdoc_options += ['--title', "Rubinius::SetTrace #{Rubinius::SetTrace::VERSION} Documentation"]

end
