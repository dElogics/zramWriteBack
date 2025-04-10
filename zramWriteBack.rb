#! /usr/bin/ruby
require 'optparse'

def parse_options
	options = {}

	parser = OptionParser.new do |opts|
		opts.banner = "Usage: example.rb [options]"

		opts.on("-z", "--zram DEVICE", String, "zram device (required)") do |z|
			options[:zram] = z
		end

		opts.on("-t", "--time SECONDS", Integer, "time interval in seconds (required)") do |t|
			options[:time] = t
		end

		opts.on("-h", "--help", "Prints this help") do
			puts opts
			exit
		end
	end

	begin
		parser.parse!
		mandatory = [:zram, :time]
		missing = mandatory.select { |param| options[param].nil? }
		unless missing.empty?
			raise OptionParser::MissingArgument.new(missing.join(', '))
		end
	rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
		puts "Error: #{e.message}"
		puts parser
		exit 1
	end

	options
end
options = parse_options

idleFile = File.open("/sys/block/zram#{options[:zram]}/idle", "w")
writebackFile = File.open("/sys/block/zram#{options[:zram]}/writeback", "w")
while true
	idleFile.truncate(0)
	# Write the content to the file
	idleFile.write('all')
	# Rewind the file pointer to the beginning of the file
	idleFile.rewind
	sleep options[:time]
	writebackFile.truncate(0)
	# Write the content to the file
	writebackFile.write('idle')
	# Rewind the file pointer to the beginning of the file
	writebackFile.rewind
end
