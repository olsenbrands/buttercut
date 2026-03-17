#!/usr/bin/env ruby
# Generates ~/.buttercut-env.json for the current machine.
# Detects hostname, user, and paths automatically.
# Run: ruby .claude/skills/setup/configure-machine.rb

require "json"
require "fileutils"

CONFIG_PATH = File.expand_path("~/.buttercut-env.json")

if File.exist?(CONFIG_PATH)
  puts "~/.buttercut-env.json already exists:"
  puts File.read(CONFIG_PATH)
  puts
  print "Overwrite? (y/N): "
  answer = $stdin.gets&.strip&.downcase
  exit 0 unless answer == "y"
end

hostname = `hostname -s`.strip
user = ENV["USER"]
home = ENV["HOME"]
repo = Dir.pwd

# Detect vault path (Obsidian syncs to same relative path on all machines)
vault_candidates = [
  File.join(home, "Olsen Brands Management"),
  File.join(home, "Library/Mobile Documents/iCloud~md~obsidian/Documents/Olsen Brands Management")
]
vault_path = vault_candidates.find { |p| Dir.exist?(p) }

unless vault_path
  puts "WARNING: Could not find Obsidian vault. Searched:"
  vault_candidates.each { |p| puts "  - #{p}" }
  puts "Set vault_path manually in #{CONFIG_PATH} after generation."
  vault_path = File.join(home, "Olsen Brands Management")
end

# Detect whisperx location
whisperx_candidates = [
  File.join(home, ".buttercut/venv/bin/whisperx"),
  File.join(home, ".buttercut/whisperx"),
  `which whisperx 2>/dev/null`.strip
]
whisperx_bin = whisperx_candidates.find { |p| !p.empty? && File.exist?(p) }
whisperx_bin ||= File.join(home, ".buttercut/venv/bin/whisperx")

# Detect iCloud Video Inbox
icloud_inbox = File.join(home, "Library/Mobile Documents/com~apple~CloudDocs/ButterCut Video Inbox")
video_inbox = Dir.exist?(icloud_inbox) ? icloud_inbox : File.join(home, "ButterCut Video Inbox")

# Build config
config = {
  machine: hostname,
  description: "Auto-configured on #{Time.now.strftime('%Y-%m-%d')}",
  vault_path: vault_path,
  vault_skills_path: File.join(vault_path, "Skills"),
  buttercut_repo: repo,
  libraries_path: File.join(repo, "libraries"),
  remotion_path: File.join(repo, "remotion"),
  remotion_public: File.join(repo, "remotion/public"),
  remotion_out: File.join(repo, "remotion/out"),
  whisperx_bin: whisperx_bin,
  silence_detector: File.join(repo, ".claude/skills/transcribe-audio/detect_silence.rb"),
  video_inbox: video_inbox,
  broll_archive: File.join(home, "Dont Sleep On AI/Images"),
  api_keys: {
    gemini: "REPLACE_WITH_YOUR_GEMINI_API_KEY",
    freesound_client_id: "LJUZyMJT1pIGNGFHRBb9",
    freesound_api_key: "cF8lgWG2phCvOF0XbAkuZ8myDR0M6svsSW2blSmN",
    pexels: "KzHGLkvxxacTfdfneoP90f1kHlRQOJ8SJGhTz6yhEL9tWBnjC8lQypnH",
    pixabay: "55058487-1ea2b3e0a47026bfd6ca1e89f",
    unsplash_access_key: "uoUYZdBjFzqpbEcJqT21lH5-ggYmtsgu9WhAnABtAgo",
    unsplash_secret_key: "_6nbRKaWmdfB3WO4THbeSvdo6GGSIMfvnaouLhv9Q8I",
    giphy: "bmiLbhi9b9NaYrZ9CWpVWmwxsjsMvNCY"
  },
  gemini_model: "gemini-2.5-flash-preview-image-generation"
}

File.write(CONFIG_PATH, JSON.pretty_generate(config) + "\n")

puts "Created #{CONFIG_PATH}:"
puts
puts JSON.pretty_generate(config)
puts
puts "ACTION REQUIRED:" if config[:api_keys][:gemini].include?("REPLACE")
puts "  - Set your Gemini API key in #{CONFIG_PATH}" if config[:api_keys][:gemini].include?("REPLACE")

# Check and create skill symlink
skill_symlink = File.join(home, ".claude/skills/video-editor")
skill_target = File.join(vault_path, "Skills/video-editor")

if !File.symlink?(skill_symlink) && Dir.exist?(skill_target)
  FileUtils.mkdir_p(File.join(home, ".claude/skills"))
  File.symlink(skill_target, skill_symlink)
  puts "  - Created symlink: #{skill_symlink} -> #{skill_target}"
elsif File.symlink?(skill_symlink)
  puts "  - Skill symlink already exists: #{skill_symlink}"
else
  puts "  - Skill symlink NOT created (vault skill not found at #{skill_target})"
end
