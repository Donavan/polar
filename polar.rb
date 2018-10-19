#!/usr/bin/env ruby
require 'pry'
require_relative 'polar_shared'

$config = File.open('config.yml', 'r') { |f| YAML.load(f.read) }
data    = read_data(ARGV[0])
multi_file_render(data, ARGV[0])

binding.pry if Nenv.debug?
puts 'done'

