#!/usr/bin/env ruby

require 'json'
require 'fileutils'
require 'find'
require 'shellwords'

# Configuration
SOURCE_DIR = 'source-images/fluentui-emojis/assets'
ANIMATED_SOURCE_DIR = 'source-images/animated'
OUTPUT_DIR = 'processed-emojis'

VALID_SKIN_TONES = ['Light', 'Medium', 'Dark', 'Medium-Light', 'Medium-Dark']

# Helper method to process an image file
def process_image(source_path, destination_path)
  # TODO: Implement image processing logic here
  # For now, we'll just copy the file
  FileUtils.cp(source_path, destination_path)
end

# Helper method to process an animated image file
def process_animated_image(source_path, destination_path)
  lowercase_icon_name = File.basename(source_path, ".*").downcase.gsub(' ', '_')
  output_filename = "#{lowercase_icon_name}_a_l0.webp"
  output_path = File.join(destination_path, output_filename)
  
  FileUtils.mkdir_p(File.dirname(output_path))
  
  # Use Shellwords.escape to properly handle paths with spaces
  escaped_source_path = Shellwords.escape(source_path)
  escaped_output_path = Shellwords.escape(output_path)
  
  command = "./apng2webp.rb -i #{escaped_source_path} -o #{escaped_output_path}"
  system(command)
end

# Find matching directory for animated image
def find_matching_directory(base_name)
  matching_dir = nil
  Find.find(OUTPUT_DIR) do |path|
    if File.directory?(path) && File.basename(path).downcase == base_name.downcase
      matching_dir = path
      break
    end
  end
  matching_dir
end

# Process a single emoji directory
def process_emoji_directory(dir_path)
  # ... [The content of this method remains unchanged] ...
end

# Extract base name and skin tone from filename
def extract_name_and_skin_tone(filename, all_filenames)
  if filename.end_with?("Skin Tone.png")
    parts = filename.split
    skin_tone_index = parts.index { |part| VALID_SKIN_TONES.include?(part) }
    if skin_tone_index
      skin_tone = parts[skin_tone_index]
      base_name = parts[0...skin_tone_index].join(' ')
      return [base_name, skin_tone]
    end
  end
  
  base_name = File.basename(filename, ".png")
  if all_filenames.any? { |f| f.start_with?(base_name) && f.end_with?("Skin Tone.png") }
    return [base_name, "Default"]
  else
    return [base_name, nil]
  end
end

# Process animated images
def process_animated_images
  all_filenames = Dir.glob(File.join(ANIMATED_SOURCE_DIR, '**', '*.png')).map { |f| File.basename(f) }
  
  Dir.glob(File.join(ANIMATED_SOURCE_DIR, '**', '*.png')).each do |file_path|
    base_name, skin_tone = extract_name_and_skin_tone(File.basename(file_path), all_filenames)
    matching_dir = find_matching_directory(base_name)
    
    if matching_dir
      destination_path = skin_tone ? File.join(matching_dir, skin_tone, '3D') : File.join(matching_dir, '3D')
      process_animated_image(file_path, destination_path)
    else
      puts "Warning: No matching directory found for #{base_name}"
    end
  end
end

# Main execution
Dir.glob(File.join(SOURCE_DIR, '*')).each do |emoji_dir|
  process_emoji_directory(emoji_dir)
end

process_animated_images()

puts "Processing complete. Check the '#{OUTPUT_DIR}' directory for results."
