#!/usr/bin/env rake
# Are we Rubinius? We'll test by checking the specific function we need.
raise RuntimeError, 'This package is for Rubinius!' unless
  Object.constants.include?('Rubinius') && 
  Rubinius.constants.include?('VM') 

require 'rubygems'

ROOT_DIR = File.dirname(__FILE__)
Gemspec_filename = 'rbx-tracer.gemspec'

def gemspec
  @gemspec ||= eval(File.read(Gemspec_filename), binding, Gemspec_filename)
end

require 'rubygems/package_task'
desc "Build the gem"
task :package=>:gem
task :gem=>:gemspec do
  Dir.chdir(ROOT_DIR) do
    sh "gem build #{Gemspec_filename}"
  end
end

desc "Install the gem locally"
task :install => :gem do
  Dir.chdir(ROOT_DIR) do
    sh %{gem install --local #{gemspec.name}}
  end
end

require 'rbconfig'
RUBY_PATH = File.join(RbConfig::CONFIG['bindir'],  
                      RbConfig::CONFIG['RUBY_INSTALL_NAME'])

def run_standalone_ruby_files(list)
  puts '*' * 40
  list.each do |ruby_file|
    system(RUBY_PATH, ruby_file)
  end
end

def run_standalone_ruby_file(directory)
  puts ('*' * 10) + ' ' + directory + ' ' + ('*' * 10)
  Dir.chdir(directory) do
    Dir.glob('*.rb').each do |ruby_file|
      puts(('-' * 20) + ' ' + ruby_file + ' ' + ('-' * 20))
      system(RUBY_PATH, ruby_file)
    end
  end
end

desc 'Create a GNU-style ChangeLog via git2cl'
task :ChangeLog do
  system('git log --pretty --numstat --summary | git2cl > ChangeLog')
end

require 'rake/testtask'
desc "Test everything."
Rake::TestTask.new(:test) do |t|
  t.test_files = FileList['test/test-*.rb']
  # t.pattern = 'test/**/*test-*.rb' # instead of above
  t.options = '--verbose' if $VERBOSE
end

desc "same as test"
task :check => :test

desc 'Test everything - unit tests for now.'
task :default => :test

desc "Run each Ruby app file in standalone mode."
task :'check:app' do
  run_standalone_ruby_file(File.join(%W(#{ROOT_DIR} app)))
end

desc "Default action is same as 'test'."
task :default => :test

desc "Generate the gemspec"
task :generate do
  puts gemspec.to_ruby
end

desc "Validate the gemspec"
task :gemspec do
  gemspec.validate
end

# ---------  RDoc Documentation ------
require 'rdoc/task'
desc "Generate rdoc documentation"
Rake::RDocTask.new("rdoc") do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.rdoc_files.include(%w(lib/set_trace.rb app/*.rb))
end

desc "Same as rdoc"
task :doc => :rdoc

task :clobber_package do
  FileUtils.rm_rf File.join(ROOT_DIR, 'pkg')
end

task :clobber_rdoc do
  FileUtils.rm_rf File.join(ROOT_DIR, 'doc')
end

desc "Remove built files"
task :clean => [:clobber_package, :clobber_rdoc]
