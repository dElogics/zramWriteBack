#! /usr/bin/ruby
require 'optparse'

def parse_options
	options = {}

	parser = OptionParser.new do |opts|
		opts.banner = "Usage: example.rb [options]"

		opts.on("-z", "--zram INT", String, "zram device integer (required)") do |z|
			options[:zram] = z.to_i
		end

		opts.on("-t", "--time [SECONDS]", Integer, "time interval in seconds") do |t|
			options[:time] = t.to_i
		end
		
		opts.on("--warnth [WARN-PERCENTAGE]", String, "Warning threshold value") do |z|
			options[:warnth] = z.to_i
		end
		
		opts.on("--criticalth [CRITICAL-PERCENTAGE]", String, "Critical threshold value") do |z|
			options[:criticalth] = z.to_i
		end

		opts.on("-h", "--help", "Prints this help") do
			puts opts
			exit
		end
	end

	begin
		parser.parse!
		mandatory = [:zram]
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
$options = parse_options
$options[:time] = 300 if $options[:time] == nil
$options[:criticalth] = 90 if $options[:criticalth] == nil
$options[:warnth] = 60 if $options[:warnth] == nil

#How much reduction in -t for zram memory utilization between warnth criticalth for each percentage
$timeReduction = ($options[:time].to_f/($options[:criticalth].to_f - $options[:warnth].to_f)).round
# Immediate flush (1s gap) if -t is too low.
$timeReduction = $options[:time] if $timeReduction <= 0

$memstat = File.open("/sys/devices/virtual/block/zram#{$options[:zram]}/mm_stat", "r")
$maxMem = $memstat.read.scan(/[0-9]+/)[3].to_f
$memstat.rewind
def memUsed
	$memstat.rewind
	($memstat.read.scan(/[0-9]+/)[2].to_f)/$maxMem*100
end

$idleFile = File.open("/sys/block/zram#{$options[:zram]}/idle", "w")
$writebackFile = File.open("/sys/block/zram#{$options[:zram]}/writeback", "w")
def writeAction
	puts "DEBUG: Writing to disk because zram memory utilization is #{memUsed}"
	$idleFile.truncate(0)
	# Write the content to the file
	$idleFile.write('all')
	# Rewind the file pointer to the beginning of the file
	$idleFile.rewind
	sleepCounter = 0
	staleTime = $options[:time]
	while sleepCounter < staleTime
		if ($options[:criticalth] - memUsed <= 1)
			puts "DEBUG: emergency disk write because zram memory utilization too close (or exceeds) criticalth (#{memUsed}%)"
			sleep 1
			break
		else
# 			If zram memory utilization is lower than critical (but of course higher than warnth)
			staleTimeReduction = (memUsed - $options[:warnth])*$timeReduction
			if staleTimeReduction >= staleTime
				puts "DEBUG: emergency disk write because zram memory utilization too close (or exceeds) criticalth (#{memUsed}%) after compensatory reduction in -t"
				sleep 1
				break
			end
			staleTime = $options[:time] - staleTimeReduction
			puts "DEBUG: reduced -t to #{staleTime} because zram memory utilization (#{memUsed}%) exceeds warnth (#{$options[:warnth]})"
			sleep 1
			sleepCounter = sleepCounter+1
		end
	end
	$writebackFile.truncate(0)
	# Write the content to the file
	$writebackFile.write('idle')
	# Rewind the file pointer to the beginning of the file
	$writebackFile.rewind
end

while true
	writeAction if memUsed >= $options[:warnth]
	sleep 1
end
