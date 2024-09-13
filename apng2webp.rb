#!/usr/bin/env ruby
require 'optparse'
require 'fileutils'
require 'tmpdir'
require 'json'

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

# Compute the absolute paths of the input and output files
input_path = File.expand_path(options[:input])
output_path = File.expand_path(options[:output])

# Get the desired frame size
if options[:size]
  frame_width, frame_height = options[:size].split('x').map(&:to_i)
else
  # Use source image dimensions
  dimensions = `ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x #{input_path}`.strip
  frame_width, frame_height = dimensions.split('x').map(&:to_i)
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

# Create a temporary directory to store intermediate files
tmpdir = Dir.mktmpdir

begin
  puts "Extracting and resizing frames using ffmpeg..."
  # Change to the temporary directory
  Dir.chdir(tmpdir) do
    # Extract and resize frames from the APNG file using the apng demuxer
    ffmpeg_cmd = [
      "ffmpeg", "-f", "apng", "-i", input_path, "-fps_mode", "passthrough",
      "-vf", "scale=#{frame_width}:#{frame_height}:force_original_aspect_ratio=decrease,pad=#{frame_width}:#{frame_height}:(ow-iw)/2:(oh-ih)/2",
      "frame%04d.png"
    ]
    puts "Running command: #{ffmpeg_cmd.join(' ')}"
    result = system(*ffmpeg_cmd)
    unless result
      puts "Error: Failed to extract and resize frames using ffmpeg."
      exit 1
    end
  end

  # Get list of extracted frames
  frames = Dir.glob(File.join(tmpdir, 'frame*.png')).sort
  if frames.empty?
    puts "Error: No frames were extracted."
    exit 1
  end

  puts "Number of frames extracted: #{frames.size}"

  # Obtain frame delays using ffprobe
  puts "Obtaining frame delays using ffprobe..."
  ffprobe_cmd = [
    "ffprobe", "-v", "error", "-select_streams", "v:0",
    "-show_frames", "-show_entries", "frame=pkt_pts_time,pkt_duration_time",
    "-of", "json", input_path
  ]
  puts "Running command: #{ffprobe_cmd.join(' ')}"
  ffprobe_output = `#{ffprobe_cmd.join(' ')}`
  if $?.exitstatus != 0
    puts "Error: Failed to get frame information using ffprobe."
    exit 1
  end

  # Parse ffprobe output to get frame durations
  ffprobe_data = JSON.parse(ffprobe_output)
  frames_info = ffprobe_data['frames']

  delays = []

  frames_info.each_with_index do |frame, index|
    # Extract duration
    duration = frame['pkt_duration_time']
    if duration.nil? || duration.to_f == 0.0
      # Calculate duration using difference in pts_time
      if index < frames_info.size - 1
        current_pts = frame['pkt_pts_time'].to_f
        next_pts = frames_info[index + 1]['pkt_pts_time'].to_f
        duration = next_pts - current_pts
      else
        # For the last frame, use the same duration as the previous one
        duration = delays.last / 1000.0
      end
    else
      duration = duration.to_f
    end

    # Convert duration to milliseconds
    delay_ms = (duration * 1000).round

    # Ensure delay is at least 10 ms (WebP minimum)
    delay_ms = 10 if delay_ms < 10

    delays << delay_ms
  end

  # Print frame delays
  puts "Frame delays (ms): #{delays.inspect}"

  # Ensure delays array matches frames array
  if delays.size > frames.size
    puts "Warning: More delays than frames. Truncating delays array."
    delays = delays[0...frames.size]
  elsif delays.size < frames.size
    puts "Warning: More frames than delays. Repeating last delay."
    delays += [delays.last] * (frames.size - delays.size)
  end

  # Set offsets to zero
  x_offsets = Array.new(frames.size, 0)
  y_offsets = Array.new(frames.size, 0)

  # Convert PNG frames to WebP frames
  frames.each_with_index do |png_frame, index|
    webp_frame = File.join(tmpdir, "frame#{index}.webp")
    puts "Converting frame #{index} to WebP..."
    result = system("cwebp -q #{quality} #{png_frame} -o #{webp_frame}")
    unless result
      puts "Error: Failed to convert frame #{index} to WebP."
      exit 1
    end
  end

  output_file = "output.webp"

  # Assemble frames into an animated WebP
  Dir.chdir(tmpdir) do
    puts "Assembling frames into animated WebP..."
    webpmux_cmd = ["webpmux"]

    delays.each_with_index do |delay, index|
      webp_frame = "frame#{index}.webp"
      x_offset = x_offsets[index]
      y_offset = y_offsets[index]
      webp_frame = "frame#{index}.webp"
      x_offset = x_offsets[index]
      y_offset = y_offsets[index]
      mi = 1  # 0 or 1
      bi = "+b"    # '+b' or '-b'
      frame_options = "+#{delay}+#{x_offset}+#{y_offset}+#{mi}#{bi}"

      webpmux_cmd += ["-frame", webp_frame, frame_options]
    end

    webpmux_cmd += ["-loop", "0"]
    webpmux_cmd += ["-o", output_file]

    puts "Running command: #{webpmux_cmd.join(' ')}"
    result = system(*webpmux_cmd)
    unless result
      puts "Error: Failed to assemble frames into animated WebP."
      exit 1
    end
  end

  # Move the output file to the desired output path
  FileUtils.mv(File.join(tmpdir, output_file), output_path)

  puts "Conversion complete! Output file: #{output_path}"

ensure
  # Clean up temporary files
  FileUtils.remove_entry tmpdir
end
