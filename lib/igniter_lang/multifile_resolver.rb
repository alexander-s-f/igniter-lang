# frozen_string_literal: true

require "digest"
require "json"
require "pathname"
require "set"

require_relative "parser"

module IgniterLang
  class MultifileResolver
    SYNTHETIC_MODULE = "Igniter.Multifile.Universe"

    def resolve(source_paths)
      paths = Array(source_paths).map { |path| Pathname.new(path) }
      units = paths.map { |path| source_unit(path) }
      return failure(units, parse_diagnostics(units)) if units.any? { |unit| unit.fetch("parse_errors").any? }

      missing_module = units.find { |unit| unit.fetch("module").to_s.empty? }
      return failure(units, [missing_module_diagnostic(missing_module)]) if missing_module

      sorted = units.sort_by { |unit| [unit.fetch("module"), unit.fetch("source_path")] }
      duplicate_module = duplicate_by(sorted, "module")
      return failure(sorted, [duplicate_module_diagnostic(duplicate_module)]) if duplicate_module

      stdlib_shadow = sorted.find { |u| u.fetch("module").to_s.start_with?("stdlib.") }
      return failure(sorted, [stdlib_shadow_diagnostic(stdlib_shadow)]) if stdlib_shadow

      by_module = sorted.to_h { |unit| [unit.fetch("module"), unit] }
      import_diagnostics = validate_imports(sorted, by_module)
      return failure(sorted, import_diagnostics) unless import_diagnostics.empty?

      cycle = import_cycle(sorted)
      return failure(sorted, [cycle_diagnostic(cycle)]) if cycle

      duplicate_contract = duplicate_declaration(sorted, "contract_names", module_qualified: true)
      return failure(sorted, [declaration_diagnostic("OOF-DECL-DUP-CONTRACT", "contract", duplicate_contract)]) if duplicate_contract

      duplicate_type = duplicate_declaration(sorted, "type_names")
      return failure(sorted, [declaration_diagnostic("OOF-DECL-DUP-TYPE", "type", duplicate_type)]) if duplicate_type

      duplicate_entrypoint = duplicate_entrypoint(sorted)
      return failure(sorted, [duplicate_entrypoint_diagnostic(duplicate_entrypoint)]) if duplicate_entrypoint

      source_hash = composite_source_hash(sorted)
      merged = merge_units(sorted, source_hash)
      {
        "ok" => true,
        "parsed_program" => merged,
        "source_units" => source_units_evidence(sorted),
        "source_hash" => source_hash,
        "source_path" => merged.fetch("source_path"),
        "cross_module_registry" => build_cross_module_registry(sorted),
        "per_module_imports" => build_per_module_imports(sorted),
        "per_contract_module" => build_per_contract_module(sorted)
      }
    end

    private

    # LANG-TYPED-CONTRACT-REF-PROP-P5: build per-module contract signature registry.
    # Built from parsed (pre-merge) units so module attribution is preserved.
    def build_cross_module_registry(sorted)
      sorted.each_with_object({}) do |unit, registry|
        mod_name = unit.fetch("module")
        contracts = unit.fetch("parsed").fetch("contracts", [])
        registry[mod_name] = contracts.each_with_object({}) do |contract, mod_reg|
          body = contract.fetch("body", [])
          inputs  = body.select { |d| d.fetch("kind", "") == "input" }
          outputs = body.select { |d| d.fetch("kind", "") == "output" }
          mod_reg[contract.fetch("name")] = {
            "modifier"     => contract.fetch("modifier", "pure"),
            "input_count"  => inputs.size,
            "input_names"  => inputs.map { |d| d.fetch("name") },
            "input_types"  => inputs.map { |d| d.fetch("type_annotation", "Unknown") },
            "output_names" => outputs.map { |d| d.fetch("name") },
            "output_types" => outputs.map { |d| d.fetch("type_annotation", "Unknown") },
            "single_output_type" => outputs.size == 1 ? outputs[0].fetch("type_annotation", nil) : nil,
            "source_hash"  => unit.fetch("source_hash"),
            "source_path"  => unit.fetch("source_path")
          }
        end
      end
    end

    def build_per_module_imports(sorted)
      sorted.each_with_object({}) do |unit, map|
        map[unit.fetch("module")] = unit.fetch("imports", [])
      end
    end

    def build_per_contract_module(sorted)
      sorted.each_with_object({}) do |unit, map|
        unit.fetch("contract_names").each { |name| map[name] = unit.fetch("module") }
      end
    end

    def source_unit(path)
      source = path.read(encoding: "utf-8")
      parsed = ParsedProgram.parse(source, source_path: path.to_s).to_h
      {
        "source_path" => path.to_s,
        "source" => source,
        "source_hash" => "sha256:#{Digest::SHA256.hexdigest(source)}",
        "parsed" => parsed,
        "parse_errors" => parsed.fetch("parse_errors", []),
        "module" => parsed.fetch("module", nil),
        "imports" => parsed.fetch("imports", []),
        "type_names" => parsed.fetch("types", []).map { |type| type.fetch("name") },
        "contract_names" => parsed.fetch("contracts", []).map { |contract| contract.fetch("name") },
        # LANG-MULTIFILE-VARIANT-IMPORTABLE-NAMES-P1: variant declaration names are importable
        # items (like type names). Separate key so dup-type checks and evidence stay unchanged.
        "variant_names" => parsed.fetch("variants", []).map { |variant| variant.fetch("name") },
        "entrypoint" => parsed.fetch("entrypoint", nil)
      }
    end

    def failure(units, diagnostics)
      {
        "ok" => false,
        "source_hash" => failure_source_hash(units),
        "source_path" => "multifile:error",
        "source_units" => source_units_evidence(units),
        "diagnostics" => diagnostics
      }
    end

    def parse_diagnostics(units)
      units.flat_map do |unit|
        unit.fetch("parse_errors").map do |error|
          stringify_keys(error).merge(
            "source_path" => unit.fetch("source_path"),
            "module_path" => unit.fetch("module")
          )
        end
      end
    end

    def validate_imports(units, by_module)
      units.flat_map do |unit|
        unit.fetch("imports").flat_map do |import|
          import_path = import.fetch("module_path")
          if stdlib_path?(import_path)
            unless stdlib_module_known?(import_path)
              next [diagnostic(
                "OOF-IMP2",
                "unknown stdlib module path '#{import_path}' from module '#{unit.fetch("module")}'",
                "import:#{import_path}",
                source_path: unit.fetch("source_path"),
                module_path: unit.fetch("module"),
                import_path: import_path
              )]
            end
            names = import.fetch("names", nil)
            next [] unless names
            next names.reject { |name| stdlib_name_known?(import_path, name) }.map do |name|
              diagnostic(
                "OOF-IMP3",
                "unknown name '#{name}' in stdlib module '#{import_path}'",
                "import:#{import_path}.{#{name}}",
                source_path: unit.fetch("source_path"),
                module_path: unit.fetch("module"),
                import_path: import_path,
                missing_name: name
              )
            end
          end
          target = by_module[import_path]
          unless target
            next [diagnostic(
              "OOF-IMP2",
              "unknown import path '#{import_path}' from module '#{unit.fetch("module")}'",
              "import:#{import_path}",
              source_path: unit.fetch("source_path"),
              module_path: unit.fetch("module"),
              import_path: import_path
            )]
          end

          names = import.fetch("names", nil)
          next [] unless names

          exported = target.fetch("type_names") + target.fetch("contract_names") + target.fetch("variant_names", [])
          names.reject { |name| exported.include?(name) }.map do |name|
            diagnostic(
              "OOF-IMP3",
              "unknown import name '#{name}' from '#{import_path}' in module '#{unit.fetch("module")}'",
              "import:#{import_path}.{#{name}}",
              source_path: unit.fetch("source_path"),
              module_path: unit.fetch("module"),
              import_path: import_path,
              missing_name: name
            )
          end
        end
      end
    end

    def stdlib_path?(import_path)
      import_path.start_with?("stdlib.")
    end

    def stdlib_module_known?(import_path)
      stdlib_module_table.key?(import_path)
    end

    def stdlib_name_known?(import_path, name)
      stdlib_module_table.fetch(import_path, Set.new).include?(name)
    end

    def stdlib_module_table
      @stdlib_module_table ||= begin
        inventory_path = File.expand_path("../../docs/spec/stdlib-inventory.json", __dir__)
        inventory = JSON.parse(File.read(inventory_path, encoding: "utf-8"))
        table = Hash.new { |h, k| h[k] = Set.new }
        inventory.fetch("entries", []).each do |entry|
          canon = entry.fetch("canonical_name")
          parts = canon.split(".")
          next unless parts.length >= 3 && parts[0] == "stdlib"
          module_path = parts[0...-1].join(".")
          table[module_path]
          entry.fetch("aliases", []).each do |al|
            table[module_path].add(al.fetch("name")) if al.fetch("kind") == "source_alias"
          end
        end
        table.transform_values { |set| set.freeze }.freeze
      end
    end

    def stdlib_shadow_diagnostic(unit)
      diagnostic(
        "OOF-IMP6",
        "user source file declares stdlib namespace path '#{unit.fetch("module")}' — stdlib.* is reserved",
        "module:#{unit.fetch("module")}",
        source_path: unit.fetch("source_path"),
        module_path: unit.fetch("module")
      )
    end

    def import_cycle(units)
      graph = units.to_h do |unit|
        [unit.fetch("module"), unit.fetch("imports").map { |import| import.fetch("module_path") }.sort]
      end
      visiting = {}
      visited = {}
      stack = []

      visit = lambda do |mod|
        return nil if visited[mod]
        if visiting[mod]
          index = stack.index(mod) || 0
          return stack[index..] + [mod]
        end

        visiting[mod] = true
        stack << mod
        graph.fetch(mod, []).each do |dep|
          next unless graph.key?(dep)
          found = visit.call(dep)
          return found if found
        end
        stack.pop
        visiting.delete(mod)
        visited[mod] = true
        nil
      end

      graph.keys.sort.each do |mod|
        found = visit.call(mod)
        return found if found
      end
      nil
    end

    def merge_units(units, source_hash)
      first = units.first.fetch("parsed")
      entrypoints = units.filter_map { |unit| unit.fetch("entrypoint") }
      merged = first.merge(
        "source_path" => "multifile:#{source_hash.delete_prefix("sha256:")[0, 16]}",
        "source_hash" => source_hash,
        "module" => SYNTHETIC_MODULE,
        "imports" => [],
        "traits" => units.flat_map { |unit| unit.fetch("parsed").fetch("traits", []) },
        "impls" => units.flat_map { |unit| unit.fetch("parsed").fetch("impls", []) },
        "contract_shapes" => units.flat_map { |unit| unit.fetch("parsed").fetch("contract_shapes", []) },
        # LANG-PACKAGE-CONTRACT-IDENTITY-P2 (FRUT-P08): the merge collapses all
        # modules into the synthetic universe, which would lose per-contract module
        # identity. Tag each contract with its ORIGIN module so `contract_id` stays
        # module-qualified (`IgKick.Plugin.Render`, not `<universe>.Render`) — this
        # is what makes two-plugin `Render` distinguishable + qualified call_contract
        # resolve.
        "contracts" => units.flat_map { |unit|
          origin = unit.fetch("parsed").fetch("module", nil)
          unit.fetch("parsed").fetch("contracts", []).map { |c| c.merge("origin_module" => origin) }
        },
        "types" => units.flat_map { |unit| unit.fetch("parsed").fetch("types", []) },
        "variants" => units.flat_map { |unit| unit.fetch("parsed").fetch("variants", []) },
        "functions" => units.flat_map { |unit| unit.fetch("parsed").fetch("functions", []) },
        "pipelines" => units.flat_map { |unit| unit.fetch("parsed").fetch("pipelines", []) },
        "olap_points" => units.flat_map { |unit| unit.fetch("parsed").fetch("olap_points", []) },
        "assumptions" => units.flat_map { |unit| unit.fetch("parsed").fetch("assumptions", []) },
        "profiles" => units.flat_map { |unit| unit.fetch("parsed").fetch("profiles", []) },
        "size_relations" => units.flat_map { |unit| unit.fetch("parsed").fetch("size_relations", []) },
        "entrypoint" => entrypoints.first,
        "intent_text" => nil,
        "parse_errors" => []
      )
      merged
    end

    def source_units_evidence(units)
      units.sort_by { |unit| [unit.fetch("module").to_s, unit.fetch("source_path")] }.map do |unit|
        {
          "module" => unit.fetch("module"),
          "source_path" => unit.fetch("source_path"),
          "source_hash" => unit.fetch("source_hash"),
          "types" => unit.fetch("type_names"),
          "contracts" => unit.fetch("contract_names")
        }
      end
    end

    def composite_source_hash(units)
      material = units.map do |unit|
        {
          "module" => unit.fetch("module"),
          "source_path" => unit.fetch("source_path"),
          "source_hash" => unit.fetch("source_hash"),
          "source" => unit.fetch("source")
        }
      end
      "sha256:#{Digest::SHA256.hexdigest(canonical_json(material))}"
    end

    def failure_source_hash(units)
      material = units.sort_by { |unit| unit.fetch("source_path") }.map do |unit|
        { "source_path" => unit.fetch("source_path"), "source_hash" => unit.fetch("source_hash") }
      end
      "sha256:#{Digest::SHA256.hexdigest(canonical_json(material))}"
    end

    def duplicate_by(units, key)
      units.group_by { |unit| unit.fetch(key) }.find { |_value, owners| owners.length > 1 }
    end

    # LANG-PACKAGE-CONTRACT-IDENTITY-P2 (FRUT-P08): when module_qualified, key the
    # duplicate check on the module-qualified id (`Module.Name`, the `contract_id`
    # substrate) so two modules may both declare `Render`; only a true same-module
    # duplicate trips. Types keep the flat check (follow-up: type identity).
    def duplicate_declaration(units, key, module_qualified: false)
      owners = Hash.new { |hash, name| hash[name] = [] }
      units.each do |unit|
        unit.fetch(key).each do |name|
          id = module_qualified ? "#{unit.fetch('module')}.#{name}" : name
          owners[id] << unit
        end
      end
      owners.sort.find { |_name, refs| refs.length > 1 }
    end

    def duplicate_entrypoint(units)
      owners = units.select { |unit| unit.fetch("entrypoint") }
      owners.length > 1 ? ["entrypoint", owners] : nil
    end

    def duplicate_module_diagnostic(duplicate)
      module_path, owners = duplicate
      diagnostic(
        "OOF-IMP4",
        "duplicate module declaration '#{module_path}'",
        "module:#{module_path}",
        module_path: module_path,
        module_paths: [module_path],
        source_paths: owners.map { |unit| unit.fetch("source_path") }
      )
    end

    def missing_module_diagnostic(unit)
      diagnostic(
        "OOF-IMP5",
        "missing module declaration in multi-file source unit '#{unit.fetch("source_path")}'",
        "module",
        source_path: unit.fetch("source_path")
      )
    end

    def cycle_diagnostic(cycle)
      diagnostic(
        "OOF-IMP1",
        "circular import detected: #{cycle.join(" -> ")}",
        "import_cycle",
        module_paths: cycle,
        cycle_path: cycle
      )
    end

    def declaration_diagnostic(rule, kind, duplicate)
      name, owners = duplicate
      diagnostic(
        rule,
        "duplicate #{kind} declaration '#{name}'",
        "#{kind}:#{name}",
        source_paths: owners.map { |unit| unit.fetch("source_path") },
        module_paths: owners.map { |unit| unit.fetch("module") }
      )
    end

    def duplicate_entrypoint_diagnostic(duplicate)
      _name, owners = duplicate
      diagnostic(
        "OOF-EP1",
        "duplicate entrypoint declaration across multi-file unit",
        "entrypoint",
        source_paths: owners.map { |unit| unit.fetch("source_path") },
        module_paths: owners.map { |unit| unit.fetch("module") }
      )
    end

    def diagnostic(rule, message, node, **extra)
      {
        "rule" => rule,
        "severity" => "error",
        "message" => message,
        "node" => node
      }.merge(extra.transform_keys(&:to_s)).reject { |_key, value| value.nil? || value == [] }
    end

    def canonical_json(value)
      JSON.generate(canonicalize(value))
    end

    def canonicalize(value)
      case value
      when Hash
        value.keys.sort.each_with_object({}) { |key, out| out[key.to_s] = canonicalize(value[key]) }
      when Array
        value.map { |entry| canonicalize(entry) }
      else
        value
      end
    end

    def stringify_keys(value)
      value.each_with_object({}) { |(key, entry), out| out[key.to_s] = entry }
    end
  end
end
