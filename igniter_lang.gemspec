# frozen_string_literal: true

require_relative "lib/igniter_lang/version"

Gem::Specification.new do |spec|
  spec.name = "igniter_lang"
  spec.version = IgniterLang::VERSION
  spec.summary = "Igniter-Lang alpha compiler package for the Igniter contract-native language research workspace"
  spec.description = "Igniter-Lang is an alpha prerelease compiler package providing the igc CLI for bounded contract compilation in the Igniter contract-native language research workspace. Not production-ready. Not stable. Branch/conditional if_expr and profile discovery/defaulting/finalization are excluded from this release."
  spec.authors = ["Alexander"]
  spec.email = ["alexander.s.fokin@gmail.com"]
  spec.homepage = "https://github.com/alexander-s-f/igniter-lang"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.files = Dir.chdir(__dir__) do
    Dir["lib/**/*.rb", "bin/igc", "README.md", "RELEASE_NOTES.md"].select { |path| File.file?(path) }
  end
  spec.bindir = "bin"
  spec.executables = ["igc"]
  spec.require_paths = ["lib"]

  spec.metadata = {
    "rubygems_mfa_required" => "true",
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage
  }
end
