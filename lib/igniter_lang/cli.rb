# frozen_string_literal: true

require "json"
require "pathname"

require_relative "../igniter_lang"

module IgniterLang
  module CLI
    module_function

    COMPILE_USAGE = "Usage: igc compile SOURCE --out OUT.igapp " \
                    "[--compiler-profile-source PATH.json]"
    RUN_USAGE = "Usage: igc run ARTIFACT.igapp --passport PATH.json " \
                "--input PATH.json --runtime SELECTOR " \
                "--out PATH.json --experimental"
    USAGE = "#{COMPILE_USAGE}\n#{RUN_USAGE}"

    def run(argv)
      if argv.empty? || %w[-h --help help].include?(argv.first)
        puts USAGE
        return true
      end

      command = argv.shift
      unless %w[compile run].include?(command)
        warn USAGE
        return false
      end

      return run_artifact(argv) if command == "run"

      source_path, out_path, profile_source_path = parse_compile_args(argv)
      compiler_profile_source = load_profile_source(profile_source_path) if profile_source_path
      orchestration = IgniterLang.compile(
        source_path: source_path,
        out_path: out_path,
        compiler_profile_source: compiler_profile_source
      )
      puts JSON.pretty_generate(CompilerResult.public_result(orchestration.fetch("result")))
      orchestration.fetch("status") == "ok"
    rescue ArgumentError => e
      warn e.message
      false
    end

    def run_artifact(argv)
      require_relative "experimental_igc_run"

      ExperimentalIgcRun.run(argv)
    end

    def parse_compile_args(argv)
      source = argv.shift
      raise ArgumentError, COMPILE_USAGE unless source

      out_flag = argv.shift
      out = argv.shift
      raise ArgumentError, COMPILE_USAGE unless out_flag == "--out" && out

      profile_source_path = nil
      until argv.empty?
        flag = argv.shift
        case flag
        when "--compiler-profile-source"
          path = argv.shift
          raise ArgumentError, "--compiler-profile-source requires PATH.json" unless path
          raise ArgumentError, "unsupported argument for igc compile" if profile_source_path

          profile_source_path = Pathname.new(path)
        else
          raise ArgumentError, "unsupported argument for igc compile"
        end
      end

      [Pathname.new(source), Pathname.new(out), profile_source_path]
    end

    def load_profile_source(path)
      raise ArgumentError, "compiler profile source path not found" unless path.exist?
      raise ArgumentError, "compiler profile source path must be a regular file" unless path.file?

      parsed = JSON.parse(path.read)
      raise ArgumentError, "compiler profile source JSON must be an object" unless parsed.is_a?(Hash)

      parsed
    rescue Errno::EACCES
      raise ArgumentError, "compiler profile source path is not readable"
    rescue JSON::ParserError
      raise ArgumentError, "compiler profile source file must contain valid JSON"
    end
  end
end
