#!/usr/bin/env ruby 

require 'rubygems'
require 'bin/common'

desc "freeze deps"
task :deps do 

  deps = {'beanstalk-client' => ">= 1.0.2"}

  puts "\ninstalling dependencies. this will take a few minutes."

  deps.each_pair do |dep, version|
    puts "\ninstalling #{dep} (#{version})"
    system("gem install #{dep} --version '#{version}' -i gems --no-rdoc --no-ri")
  end

end