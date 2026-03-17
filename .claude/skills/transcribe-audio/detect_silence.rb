#!/usr/bin/env ruby
# Runs FFmpeg silencedetect on a video file and outputs a JSON silence map.
# Usage: ruby detect_silence.rb <video_file> <output_json> [noise_threshold] [min_duration]
#
# Defaults: noise=-25dB, min_duration=0.2s
# Output: JSON array of {start, end, duration} silence intervals

require 'json'

if ARGV.length < 2
  puts "Usage: ruby detect_silence.rb <video_file> <output_json> [noise_db] [min_duration_s]"
  exit 1
end

video_file = ARGV[0]
output_file = ARGV[1]
noise_threshold = ARGV[2] || "-25dB"
min_duration = ARGV[3] || "0.2"

unless File.exist?(video_file)
  puts "Error: File not found: #{video_file}"
  exit 1
end

require 'shellwords'

# Run FFmpeg silencedetect — output goes to stderr
cmd = "ffmpeg -i #{Shellwords.escape(video_file)} -af silencedetect=n=#{noise_threshold}:d=#{min_duration} -f null - 2>&1"

output = `#{cmd}`

# Parse silence_start / silence_end / silence_duration from FFmpeg output
silences = []
current = {}

output.each_line do |line|
  if line =~ /silence_start:\s*([\d.]+)/
    current[:start] = $1.to_f
  elsif line =~ /silence_end:\s*([\d.]+)\s*\|\s*silence_duration:\s*([\d.]+)/
    current[:end] = $1.to_f
    current[:duration] = $2.to_f
    silences << current
    current = {}
  end
end

# Get video duration for metadata
duration_output = `ffprobe -v error -show_entries format=duration -of csv=p=0 #{Shellwords.escape(video_file)}`
video_duration = duration_output.strip.to_f

result = {
  "video_path" => video_file,
  "video_duration" => video_duration,
  "noise_threshold" => noise_threshold,
  "min_silence_duration" => min_duration.to_f,
  "silence_count" => silences.length,
  "silences" => silences.map { |s| { "start" => s[:start], "end" => s[:end], "duration" => s[:duration] } }
}

File.write(output_file, JSON.pretty_generate(result))
puts "Silence map: #{output_file} (#{silences.length} silence intervals found)"
