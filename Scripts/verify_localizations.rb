#!/usr/bin/env ruby
# frozen_string_literal: true

# Fails when any supported locale is missing a key that exists in English.
# Run with: ruby Scripts/verify_localizations.rb

def entries(path)
  File.read(path).scan(/^\s*"((?:\\.|[^\"])*)"\s*=\s*"/).flatten.to_set
end

require "set"

root = File.expand_path("..", __dir__)
base_path = File.join(root, "LinkShelf/Resources/en.lproj/Localizable.strings")
base = entries(base_path)
failed = false

Dir.glob(File.join(root, "LinkShelf/Resources/*.lproj/Localizable.strings")).sort.each do |path|
  missing = base - entries(path)
  next if missing.empty?

  failed = true
  locale = File.basename(File.dirname(path), ".lproj")
  warn "#{locale}: missing #{missing.to_a.sort.join(", ")}" 
end

abort "Localization coverage check failed." if failed
puts "Localization coverage OK (#{base.size} keys across all locales)."
