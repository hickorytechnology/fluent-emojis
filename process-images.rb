require 'json'
require 'fileutils'

# Configuration
SOURCE_DIR = 'source-images/fluentui-emojis/assets'
OUTPUT_DIR = 'processed-emojis'

# Helper method to process an image file
def process_image(source_path, destination_path)
  # TODO: Implement image processing logic here
  # For now, we'll just copy the file
  FileUtils.cp(source_path, destination_path)
end

# Process a single emoji directory
def process_emoji_directory(dir_path)
  metadata_path = File.join(dir_path, 'metadata.json')
  return unless File.exist?(metadata_path)

  metadata = JSON.parse(File.read(metadata_path))
  category = metadata['group']
  emoji_name = metadata['cldr'].gsub(' ', '_').downcase

  # Get the emoji directory name
  emoji_dir_name = File.basename(dir_path)

  # Process images
  Dir.glob(File.join(dir_path, '**', '*')).each do |file_path|
    next if File.directory?(file_path) || File.basename(file_path) == 'metadata.json'

    # Determine the relative path and construct the new path
    relative_path = file_path.sub("#{SOURCE_DIR}/", '')
    parts = relative_path.split('/')
    
    # Construct the new directory path, including the emoji directory
    new_dir = File.join(OUTPUT_DIR, category, emoji_dir_name, *parts[1..-2])
    FileUtils.mkdir_p(new_dir)

    # Construct the new file name
    original_filename = File.basename(file_path)
    original_name_without_ext = File.basename(original_filename, ".*").downcase
    extension = File.extname(original_filename)

    # Check if the emoji name is already in the original filename
    if original_name_without_ext.start_with?(emoji_name)
      new_filename = original_filename.downcase
    else
      new_filename = "#{emoji_name}_#{original_name_without_ext}#{extension}".downcase
    end

    # Process and save the image
    destination_path = File.join(new_dir, new_filename)
    process_image(file_path, destination_path)
  end
end

# Main execution
Dir.glob(File.join(SOURCE_DIR, '*')).each do |emoji_dir|
  process_emoji_directory(emoji_dir)
end

puts "Processing complete. Check the '#{OUTPUT_DIR}' directory for results."
