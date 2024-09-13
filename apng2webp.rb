#!/usr/bin/env ruby
require 'optparse'
require 'fileutils'
require 'tmpdir'

# Parse command-line options
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: apng_to_webp.rb [options]"

  opts.on("-i", "--input FILE", "Input APNG file") do |v|
    options[:input] = v
  end

  opts.on("-o", "--output FILE", "Output WebP file") do |v|
    options[:output] = v
  end

  opts.on("-q", "--quality QUALITY", Integer, "Quality (0-100), default is 75") do |v|
    options[:quality] = v
  end

  opts.on("-s", "--size SIZE", "Frame size in WxH format, default is source image size") do |v|
    options[:size] = v
  end

  opts.on("-l", "--loop COUNT", Integer, "Number of times to loop the animation, default is 0 (infinite)") do |v|
    options[:loop] = v
  end

  opts.on("-h", "--help", "Displays Help") do
    puts opts
    exit
  end
end.parse!

# Validate required options
if options[:input].nil? || options[:output].nil?
  puts "Error: Input and output files are required."
  exit 1
end

quality = options[:quality] || 75
loop_count = options[:loop] || 0  # Default loop value is 0 (infinite)

# Compute the absolute paths of the input and output files
input_path = File.expand_path(options[:input])
output_path = File.expand_path(options[:output])

# Get the desired frame size
resize_filter = ""
if options[:size]
  frame_width, frame_height = options[:size].split('x').map(&:to_i)
  resize_filter = "scale=#{frame_width}:#{frame_height}:force_original_aspect_ratio=decrease,pad=#{frame_width}:#{frame_height}:(ow-iw)/2:(oh-ih)/2"
else
  # No resize filter if size is not specified
  resize_filter = "scale=trunc(iw/2)*2:trunc(ih/2)*2" # Ensures width and height are even
end

# Get source FPS using ffprobe
fps_output = `ffprobe -v 0 -of csv=p=0 -select_streams v:0 -show_entries stream=r_frame_rate #{input_path}`.strip
if fps_output.empty?
  puts "Error: Unable to determine source FPS."
  exit 1
end

# Parse FPS fraction
fps_numerator, fps_denominator = fps_output.split('/').map(&:to_f)
if fps_denominator == 0
  puts "Error: Invalid FPS value."
  exit 1
end
input_fps = fps_numerator / fps_denominator
puts "Source FPS: #{input_fps}"

# Use ffmpeg with the libwebp_anim codec to convert the APNG directly to animated WebP
ffmpeg_cmd = [
  "ffmpeg", "-f", "apng", "-i", input_path,
  "-vf", "#{resize_filter},format=yuva420p", # Resize and convert to YUVA format for transparency and lossless encoding
  "-c:v", "libwebp_anim", 
  "-q:v", quality.to_s, 
  "-r", input_fps.to_s,   # Set the frame rate
  "-loop", loop_count.to_s, # Set loop count (default 0 for infinite loop)
  output_path
]

puts "Running command: #{ffmpeg_cmd.join(' ')}"
result = system(*ffmpeg_cmd)

if result
  puts "Conversion complete! Output file: #{output_path}"
else
  puts "Error: Failed to convert APNG to WebP."
  exit 1
end
