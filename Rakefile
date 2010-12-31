#!/usr/bin/env rake
# Are we Rubinius? We'll test by checking the specific function we need.
raise RuntimeError, 'This package is for Rubinius 1.2 or 1.2.1dev only!' unless
  Object.constants.include?('Rubinius') && 
  Rubinius.constants.include?('VM') && 
  %w(1.2 1.2.0 1.2.1dev).member?(Rubinius::VERSION)

require 'rubygems'
require 'rake/gempackagetask'
require 'rake/rdoctask'
require 'rake/testtask'

ROOT_DIR = File.dirname(__FILE__)

def gemspec
  @gemspec ||= eval(File.read('.gemspec'), binding, '.gemspec')
end

desc "Build the gem"
task :package=>:gem
task :gem=>:gemspec do
  Dir.chdir(ROOT_DIR) do
    sh "gem build .gemspec"
    FileUtils.mkdir_p 'pkg'
    FileUtils.mv("#{gemspec.name}-#{gemspec.version}-universal-rubinius-1.2.gem", 
                 "pkg/#{gemspec.name}-#{gemspec.version}-universal-rubinius-1.2.gem")
  end
end

desc "Install the gem locally"
task :install => :gem do
  Dir.chdir(ROOT_DIR) do
    sh %{gem install --local pkg/#{gemspec.name}-#{gemspec.version}}
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

desc 'the tests'
Rake::TestTask.new(:'test') do |t|
  t.test_files = FileList['test/test-*.rb']
  # t.pattern = 'test/**/*test-*.rb' # instead of above
  t.verbose = true
end

desc 'Test everything - unit tests for now.'
task :default => :test

desc "Run each Ruby app file in standalone mode."
task :'check:app' do
  run_standalone_ruby_file(File.join(%W(#{ROOT_DIR} app)))
end

desc "Generate the gemspec"
task :generate do
  puts gemspec.to_ruby
end

desc "Validate the gemspec"
task :gemspec do
  gemspec.validate
end

# ---------  RDoc Documentation ------
desc "Generate rdoc documentation"
Rake::RDocTask.new("rdoc") do |rdoc|
  rdoc.rdoc_dir = 'doc'
  # rdoc.title    = "rbx-trepaning #{Rubinius::SetTrace::VERSION} Documentation"

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
