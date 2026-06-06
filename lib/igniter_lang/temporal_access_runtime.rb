# frozen_string_literal: true

require "digest"
require "json"
require "time"

module IgniterLang
  module TemporalAccessRuntime
    module Capabilities
      HISTORY_READ = "history_read"
      BIHISTORY_READ = "bihistory_read"
      BITEMPORAL_READ = BIHISTORY_READ

      module_function

      def for_axis(axis)
        case axis
        when "single", "valid_time"
          [HISTORY_READ]
        when "bitemporal"
          [BIHISTORY_READ]
        else
          []
        end
      end

      def axis_for(access_node, input_node)
        axis = access_node["axis"] || input_node["axis"]
        axis == "single" ? "valid_time" : axis
      end
    end

    module Canonical
      module_function

      def normalize(value)
        case value
        when Hash
          value.keys.sort_by(&:to_s).each_with_object({}) { |key, out| out[key.to_s] = normalize(value[key]) }
        when Array
          value.map { |item| normalize(item) }
        else
          value
        end
      end

      def json(value)
        JSON.generate(normalize(value))
      end

      def pretty(value)
        "#{JSON.pretty_generate(normalize(value))}\n"
      end

      def hash(value)
        "sha256:#{Digest::SHA256.hexdigest(json(value))}"
      end

      def short_hash(value)
        hash(value).split(":").last[0, 16]
      end
    end

    module Option
      ENCODING = {
        "some" => { "kind" => "some", "value" => "<value>" },
        "none" => { "kind" => "none" }
      }.freeze

      module_function

      def some(value)
        { "kind" => "some", "value" => value }
      end

      def none
        { "kind" => "none" }
      end

      def some?(value)
        value.fetch("kind") == "some"
      end

      def value(option)
        option.fetch("value")
      end
    end

    class AxisTypeError < StandardError
      attr_reader :axis, :value

      def initialize(axis, value)
        @axis = axis
        @value = value
        super("#{axis} must be ISO8601 DateTime")
      end
    end

    class CapabilityError < StandardError
      attr_reader :capability, :node

      def initialize(capability, node)
        @capability = capability
        @node = node
        super("temporal access requires capability: #{capability}")
      end
    end

    class BackendContractError < StandardError
      attr_reader :method_name, :axis

      def initialize(method_name, axis)
        @method_name = method_name
        @axis = axis
        super("temporal access backend must implement #{method_name} for #{axis}")
      end
    end

    class RuntimeMachineHook
      def initialize(backend:, capabilities: nil)
        @backend = backend
        @capabilities = Array(capabilities || infer_capabilities(backend))
        @evaluator = SemanticIRTemporalAccessEvaluator.new(backend)
      end

      def load_check(contract:, requirements: {})
        nodes = contract.fetch("nodes", [])
        temporal_inputs = temporal_inputs_for(nodes)
        checks = nodes
          .select { |node| node.fetch("kind") == "temporal_access_node" }
          .map { |node| load_check_node(node, temporal_inputs, requirements) }
        {
          "kind" => "temporal_access_hook_load_check",
          "status" => checks.all? { |check| check.fetch("status") == "ok" } ? "ok" : "blocked",
          "checks" => checks
        }
      end

      def evaluate(access_node, temporal_inputs:, inputs:)
        input_node = temporal_inputs.fetch(access_node.fetch("source_ref"))
        axis = Capabilities.axis_for(access_node, input_node)
        ensure_capabilities!(Capabilities.for_axis(axis), access_node)
        ensure_backend_contract!(axis)
        @evaluator.evaluate(access_node, temporal_inputs: temporal_inputs, inputs: inputs)
      end

      private

      def load_check_node(access_node, temporal_inputs, requirements)
        input_node = temporal_inputs.fetch(access_node.fetch("source_ref"))
        axis = Capabilities.axis_for(access_node, input_node)
        required = Capabilities.for_axis(axis)
        declared = Array(requirements.dig("capabilities", "required_caps"))
        missing_declared_caps = declared.empty? ? [] : required.reject { |capability| declared.include?(capability) }
        missing_caps = required.reject { |capability| capability_available?(capability) }
        missing_methods = backend_methods_for(axis).reject { |method_name| @backend.respond_to?(method_name) }
        {
          "node" => access_node.fetch("name"),
          "axis" => axis,
          "required_capabilities" => required,
          "declared_capabilities" => declared,
          "missing_declared_capabilities" => missing_declared_caps,
          "missing_capabilities" => missing_caps,
          "required_backend_methods" => backend_methods_for(axis).map(&:to_s),
          "missing_backend_methods" => missing_methods.map(&:to_s),
          "status" => missing_declared_caps.empty? && missing_caps.empty? && missing_methods.empty? ? "ok" : "blocked"
        }
      rescue KeyError => e
        {
          "node" => access_node.fetch("name", nil),
          "axis" => nil,
          "required_capabilities" => [],
          "declared_capabilities" => [],
          "missing_declared_capabilities" => [],
          "missing_capabilities" => [],
          "required_backend_methods" => [],
          "missing_backend_methods" => [],
          "status" => "blocked",
          "error" => e.message
        }
      end

      def ensure_capabilities!(required, access_node)
        required.each do |capability|
          raise CapabilityError.new(capability, access_node) unless capability_available?(capability)
        end
      end

      def ensure_backend_contract!(axis)
        backend_methods_for(axis).each do |method_name|
          raise BackendContractError.new(method_name, axis) unless @backend.respond_to?(method_name)
        end
      end

      def backend_methods_for(axis)
        case axis
        when "valid_time"
          [:read_as_of]
        when "bitemporal"
          [:bihistory_at]
        else
          []
        end
      end

      def capability_available?(capability)
        return true if @capabilities.include?(capability)
        return @backend.supports_capability?(capability) if @backend.respond_to?(:supports_capability?)

        false
      end

      def infer_capabilities(backend)
        capabilities = []
        capabilities << Capabilities::HISTORY_READ if backend.respond_to?(:read_as_of)
        capabilities << Capabilities::BIHISTORY_READ if backend.respond_to?(:bihistory_at)
        capabilities
      end

      def temporal_inputs_for(nodes)
        nodes
          .select { |node| node.fetch("kind") == "temporal_input_node" }
          .to_h { |node| [node.fetch("name"), node] }
      end
    end

    class SemanticIRTemporalAccessEvaluator
      def initialize(backend)
        @backend = backend
      end

      def evaluate(access_node, temporal_inputs:, inputs:)
        raise ArgumentError, "expected temporal_access_node" unless access_node.fetch("kind") == "temporal_access_node"
        raise ArgumentError, "only point temporal access is supported" unless access_node.fetch("access") == "point"

        input_node = temporal_inputs.fetch(access_node.fetch("source_ref"))
        axis = normalized_axis(access_node, input_node)
        case axis
        when "valid_time"
          evaluate_valid_time(access_node, input_node, inputs)
        when "bitemporal"
          evaluate_bitemporal(access_node, input_node, inputs)
        else
          raise ArgumentError, "unsupported temporal axis: #{axis}"
        end
      end

      private

      def evaluate_valid_time(access_node, input_node, inputs)
        time_ref = access_node["time_ref"] || input_node.fetch("as_of_ref")
        subject = render_ref(input_node.fetch("store_ref"), inputs)
        result, observation = @backend.read_as_of(subject, inputs.fetch(time_ref))
        envelope(access_node, "valid_time", result, observation, selected_ref_key: "selected_append_ref", rel: "selected_append")
      end

      def evaluate_bitemporal(access_node, input_node, inputs)
        valid_time_ref = access_node.fetch("valid_time_ref")
        transaction_time_ref = access_node.fetch("transaction_time_ref")
        history_ref = render_ref(input_node.fetch("history_ref") { input_node.fetch("store_ref") }, inputs)
        result, observation = @backend.bihistory_at(
          history_ref,
          vt: inputs.fetch(valid_time_ref),
          tt: inputs.fetch(transaction_time_ref),
          node_name: access_node.fetch("name")
        )
        envelope(access_node, "bitemporal", result, observation, selected_ref_key: "selected_event_ref", rel: "selected_event")
      end

      def envelope(access_node, axis, result, observation, selected_ref_key:, rel:)
        selected_ref = observation[selected_ref_key]
        {
          "kind" => "temporal_access_evaluation",
          "node" => access_node.fetch("name"),
          "axis" => axis,
          "result" => result,
          "observation" => observation,
          "evidence_links" => selected_ref ? [
            {
              "rel" => rel,
              "from" => observation.fetch("observation_id"),
              "to" => selected_ref
            }
          ] : []
        }
      end

      def normalized_axis(access_node, input_node)
        axis = access_node["axis"] || input_node["axis"]
        return "valid_time" if axis == "single"

        axis
      end

      def render_ref(template, inputs)
        template.gsub(/\{([^}]+)\}/) do
          inputs.fetch(Regexp.last_match(1))
        end
      end
    end

    class MemoryBackend
      attr_reader :append_observations, :events, :access_observations

      def initialize
        @append_observations = []
        @events = Hash.new { |hash, key| hash[key] = [] }
        @access_observations = []
      end

      def seed_append_observations(observations)
        observations.each do |observation|
          append(observation.fetch("subject"), observation.fetch("valid_from"), observation.fetch("value"),
                 value_type: observation.fetch("value_type"))
        end
      end

      def append(subject, valid_from, value, value_type:)
        payload = {
          "kind" => "history_append_observation",
          "subject" => subject,
          "valid_from" => valid_from,
          "value" => value,
          "value_type" => value_type
        }
        observation = payload.merge(
          "observation_id" => "obs/history_append/#{Canonical.short_hash(payload)}",
          "observed_at" => valid_from,
          "temporal" => {
            "axis" => "valid_time",
            "as_of" => valid_from,
            "lifecycle" => "durable"
          }
        )
        @append_observations << observation
        observation
      end

      def history_at(subject, as_of)
        as_of_time = parse_axis!("as_of", as_of)
        selected = @append_observations
          .select { |obs| obs.fetch("subject") == subject && Time.iso8601(obs.fetch("valid_from")) <= as_of_time }
          .max_by { |obs| Time.iso8601(obs.fetch("valid_from")) }
        result = selected ? Option.some(selected.fetch("value")) : Option.none
        observation = history_access_observation(subject, as_of, selected, result)
        @access_observations << observation
        [result, observation]
      end

      def read_as_of(subject, as_of)
        history_at(subject, as_of)
      end

      def seed(events)
        events.each { |event| append_bihistory_event(event) }
      end

      def append_bihistory_event(event)
        history_ref = event.fetch("history_ref")
        @events[history_ref] << event
        @events[history_ref].sort_by! { |entry| [entry.fetch("valid_from"), entry.fetch("tx_from"), entry.fetch("event_id")] }
      end

      def bihistory_at(history_ref, vt:, tt:, node_name:)
        vt_time = parse_axis!("vt", vt)
        tt_time = parse_axis!("tt", tt)
        selected = @events.fetch(history_ref, [])
          .select { |event| covers_valid_time?(event, vt_time) && Time.iso8601(event.fetch("tx_from")) <= tt_time }
          .max_by { |event| [Time.iso8601(event.fetch("tx_from")), event.fetch("event_id")] }
        result = selected ? Option.some(selected.fetch("value")) : Option.none
        observation = bihistory_access_observation(history_ref, vt, tt, node_name, selected, result)
        @access_observations << observation
        [result, observation]
      end

      private

      def parse_axis!(axis, value)
        raise AxisTypeError.new(axis, value) unless value.is_a?(String)

        Time.iso8601(value)
      rescue ArgumentError
        raise AxisTypeError.new(axis, value)
      end

      def covers_valid_time?(event, vt_time)
        valid_from = Time.iso8601(event.fetch("valid_from"))
        valid_until = Time.iso8601(event.fetch("valid_until"))
        valid_from <= vt_time && vt_time < valid_until
      end

      def history_access_observation(subject, as_of, selected, result)
        payload = {
          "kind" => "history_access_observation",
          "subject" => subject,
          "as_of" => as_of,
          "access" => "point",
          "selected_append_ref" => selected&.fetch("observation_id"),
          "result" => result,
          "option_encoding" => Option::ENCODING
        }
        payload.merge(
          "observation_id" => "obs/history_access/#{Canonical.short_hash(payload)}",
          "observed_at" => as_of,
          "temporal" => {
            "axis" => "valid_time",
            "as_of" => as_of,
            "lifecycle" => "session"
          }
        )
      end

      def bihistory_access_observation(history_ref, vt, tt, node_name, selected, result)
        payload = {
          "kind" => "bihistory_access_observation",
          "history_ref" => history_ref,
          "node" => node_name,
          "axis" => "bitemporal",
          "valid_time" => vt,
          "transaction_time" => tt,
          "selected_event_ref" => selected&.fetch("event_id"),
          "result" => result,
          "option_encoding" => Option::ENCODING
        }
        payload.merge(
          "observation_id" => "obs/bihistory_access/#{Canonical.short_hash(payload)}",
          "observed_at" => tt,
          "temporal" => {
            "valid_time" => vt,
            "transaction_time" => tt,
            "lifecycle" => "audit"
          }
        )
      end
    end
  end
end
