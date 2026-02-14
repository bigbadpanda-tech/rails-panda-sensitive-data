begin
  require "bundler/gem_tasks"
  require "rspec/core/rake_task"
  require "rubocop/rake_task"
rescue LoadError
  puts "You must `gem install bundler` and `bundle install` to run rake tasks"
end

desc "Run specs"
RSpec::Core::RakeTask.new(:spec)

desc "Run RuboCop checks"
RuboCop::RakeTask.new(:rubocop)

task default: %i[spec rubocop]
