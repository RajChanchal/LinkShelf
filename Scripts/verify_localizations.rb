#!/usr/bin/env ruby
# frozen_string_literal: true

# Fails when any supported locale is missing a key that exists in English.
# Run with: ruby Scripts/verify_localizations.rb

require "set"
require "json"

root = File.expand_path("..", __dir__)
catalog_path = File.join(root, "LinkShelf/Resources/Localizable.xcstrings")
catalog = JSON.parse(File.read(catalog_path))
strings = catalog.fetch("strings")
base = strings.select { |_key, entry| entry.dig("localizations", "en", "stringUnit", "value") }.keys.to_set
locales = strings.values.flat_map { |entry| entry.fetch("localizations", {}).keys }.uniq.sort
failed = false

locales.each do |locale|
  translated = strings.each_with_object(Set.new) do |(key, entry), result|
    result << key if entry.dig("localizations", locale, "stringUnit", "value")
  end
  missing = base - translated
  next if missing.empty?

  failed = true
  warn "#{locale}: missing #{missing.to_a.sort.join(", ")}" 
end

abort "Localization coverage check failed." if failed
puts "Localization coverage OK (#{base.size} keys across all locales)."
