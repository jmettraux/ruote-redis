
require 'rubygems'
require 'rake'

require 'lib/ruote/redis/version.rb'

#
# CLEAN

require 'rake/clean'
CLEAN.include('pkg', 'tmp', 'html')
task :default => [ :clean ]


#
# GEM

require 'jeweler'

Jeweler::Tasks.new do |gem|

  gem.version = Ruote::Redis::VERSION
  gem.name = 'ruote-redis'
  gem.summary = 'Redis storage for ruote (a ruby workflow engine)'
  gem.description = %{
Redis storage for ruote (a ruby workflow engine)
  }.strip
  gem.email = 'jmettraux@gmail.com'
  gem.homepage = 'http://github.com/jmettraux/ruote-redis'
  gem.authors = [ 'John Mettraux' ]
  gem.rubyforge_project = 'ruote'

  #gem.test_file = 'test/test.rb'

  gem.add_dependency 'ruote', ">= #{Ruote::Redis::VERSION}"
  gem.add_dependency 'redis', '>= 2.0.5'
  gem.add_development_dependency 'yard'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'jeweler'

  # gemspec spec : http://www.rubygems.org/read/chapter/20
end
Jeweler::GemcutterTasks.new


#
# DOC

#
# make sure to have rdoc 2.5.x to run that
#
require 'rake/rdoctask'
Rake::RDocTask.new do |rd|

  rd.main = 'README.rdoc'
  rd.rdoc_dir = 'rdoc/ruote-redis_rdoc'

  rd.rdoc_files.include(
    'README.rdoc', 'CHANGELOG.txt', 'CREDITS.txt', 'lib/**/*.rb')

  rd.title = "ruote-redis #{Ruote::Redis::VERSION}"
end


#
# TO THE WEB

task :upload_rdoc => [ :clean, :rdoc ] do

  account = 'jmettraux@rubyforge.org'
  webdir = '/var/www/gforge-projects/ruote'

  sh "rsync -azv -e ssh rdoc/ruote-redis_rdoc #{account}:#{webdir}/"
end

