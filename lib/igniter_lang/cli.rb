# frozen_string_literal: true

require "json"
require "pathname"
require "digest"

require_relative "../igniter_lang"

module IgniterLang
  module CLI
    module_function

    COMPILE_USAGE = "Usage: igc compile SOURCE --out OUT.igapp " \
                    "[--compiler-profile-source PATH.json]"
    RUN_USAGE = "Usage: igc run ARTIFACT.igapp --passport PATH.json " \
                "--input PATH.json --runtime SELECTOR " \
                "--out PATH.json --experimental"
    CHECK_USAGE = "Usage: igc check SOURCE [SOURCE ...] [--json]"
    USAGE = "#{COMPILE_USAGE}\n#{CHECK_USAGE}\n#{RUN_USAGE}"

    def exit_code(argv)
      return run_check(argv.drop(1)) if argv.first == "check"

      run(argv) ? 0 : 1
    end

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

    def run_check(argv)
      json_mode = argv.include?("--json")
      source_paths = parse_check_args(argv)
      executable_sha256 =
        if File.file?($PROGRAM_NAME)
          "sha256:#{Digest::SHA256.file($PROGRAM_NAME).hexdigest}"
        end
      receipt = CompilerOrchestrator.new.check_sources(
        source_paths: source_paths,
        executable_sha256: executable_sha256
      )
      if json_mode
        puts JSON.pretty_generate(receipt)
      else
        diagnostics = receipt.fetch("diagnostics", [])
        puts "Canon source check: #{receipt.fetch("status")} " \
             "(#{receipt.dig("source_set", "resolved_units").length} units, " \
             "#{receipt.fetch("contract_ids").length} contracts, #{diagnostics.length} diagnostics)"
        diagnostics.each do |diagnostic|
          puts "  #{diagnostic.fetch("rule", "unknown")}: #{diagnostic.fetch("message", "")}"
        end
        puts "  #{receipt.fetch("message")}" if receipt.key?("message")
      end
      receipt.fetch("exit_code")
    rescue ArgumentError => e
      if json_mode
        puts JSON.pretty_generate(
          "kind" => "igniter_native_source_check_receipt",
          "format_version" => "0.1.0",
          "command" => "igc check",
          "toolchain" => "ruby_canon",
          "status" => "usage_error",
          "exit_code" => 2,
          "message" => e.message,
          "writes" => { "source" => [], "artifacts" => [], "reports" => [], "temporary" => [] }
        )
      else
        puts e.message
      end
      2
    rescue => e
      if json_mode
        puts JSON.pretty_generate(
          "kind" => "igniter_native_source_check_receipt",
          "format_version" => "0.1.0",
          "command" => "igc check",
          "toolchain" => "ruby_canon",
          "status" => "internal_error",
          "exit_code" => 3,
          "message" => "#{e.class}: #{e.message}",
          "writes" => { "source" => [], "artifacts" => [], "reports" => [], "temporary" => [] }
        )
      else
        puts "Canon source check: internal_error: #{e.class}: #{e.message}"
      end
      3
    end

    def parse_check_args(argv)
      raise ArgumentError, CHECK_USAGE if argv.empty?
      raise ArgumentError, CHECK_USAGE if argv.count("--json") > 1

      sources = argv.reject { |arg| arg == "--json" }
      raise ArgumentError, CHECK_USAGE if sources.empty? || sources.any? { |arg| arg.start_with?("-") }
      sources.each do |source|
        path = Pathname.new(source)
        raise ArgumentError, "igc check: source is not a regular file: #{source}" unless path.file?
      end
      sources.map { |source| Pathname.new(source) }
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

      parsed = JSON.parse(path.read(encoding: "utf-8"))
      raise ArgumentError, "compiler profile source JSON must be an object" unless parsed.is_a?(Hash)

      parsed
    rescue Errno::EACCES
      raise ArgumentError, "compiler profile source path is not readable"
    rescue JSON::ParserError
      raise ArgumentError, "compiler profile source file must contain valid JSON"
    end
  end
end
