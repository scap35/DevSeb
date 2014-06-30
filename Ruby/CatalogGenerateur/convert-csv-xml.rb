#!/usr/bin/env ruby

require 'csv2other'

if ARGV.count < 3
  puts "I need 3 parameters:"
  puts "#{__FILE__} <template> <csv_filename> <destination>"
  exit
end
template = ARGV[0]
csv_filename = ARGV[1]
destination = ARGV[2]

unless File.exist?(template)
  puts "template file is missing : #{template} not found"
  exit
end

unless File.exist?(csv_filename)
  puts "csv_filename is missing : #{csv_filename} not found"
  exit
end

if File.exist?(destination)
  puts "Destination file already exists: #{destination}"
  exit
end

ips = Csv2other.new

ips.parse(csv_filename, 'catalog_element_id')

ips.load_template template

zone_ips = File.open(destination, 'w')

ips.each do |k, t|
  @t = t
  zone_ips.puts ips.render(binding)
end

zone_ips.close
