# frozen_string_literal: true

require "digest"
require "json"

module IgniterLang
  # Phase 1 TEMPORAL executor boundary.
  #
  # Authorized scope: History[T] valid_time, proof-local MemoryBackend only.
  # All other surfaces (Ledger, BiHistory, stream, OLAP, writes, production
  # cache) are explicitly excluded and refuse before any live call.
  #
  # Guard order (token-before-gate per S3-R15-C1-P amendment):
  #   approval_token → gate_state → backend_identity → scope → cache_key → kernel
  #
  # Live reads stay blocked until gate3_authorized: true + valid token.
  module TemporalExecutor
    # Phase 1 proof-local authority URI from gate3-decision-record-v0.md §Authority Registry.
    # Source-code-parity verification only — not cryptographic authorization.
    # Any token carrying this exact string passes AT-9; issuer identity is not verified.
    # Replace with production signing (R2) before any non-proof deployment.
    GATE3_AUTHORITY_REF =
      "architect-supervisor://igniter-lang/gates/gate3/" \
      "runtime-temporal-executor/restricted-history-valid-time-v0/2026-05-09"

    PHASE1_FORMAT_VERSION = "0.1.0"
    PHASE1_SCOPE          = "History[T] valid_time"
    PHASE1_MEMORY_BACKEND_CLASS = "IgniterLang::TemporalAccessRuntime::MemoryBackend"

    # Reason codes emitted by this executor (stable identifiers for callers).
    module ReasonCode
      APPROVAL_MISSING        = "runtime.executor_approval_missing"
      APPROVAL_MALFORMED      = "runtime.executor_approval_malformed"
      AUTHORITY_UNTRUSTED     = "runtime.executor_approval_authority_untrusted"
      GATE3_CLOSED            = "runtime.temporal_gate3_closed"
      BACKEND_IDENTITY_BLOCKED = "runtime.phase1_backend_identity_blocked"
      SCOPE_EXCLUSION         = "runtime.temporal_scope_exclusion"
      NON_TEMPORAL            = SCOPE_EXCLUSION
      CACHE_MISMATCH          = "runtime.temporal_cache_schema_mismatch"
      BIHISTORY_EXCLUDED      = SCOPE_EXCLUSION
      CORE_REFUSAL            = SCOPE_EXCLUSION
      EVALUATION_READY        = "runtime.temporal_evaluation_ready"

      # Deprecated string literals from pre-S3-R18-C2-P experiment fixtures.
      # The lib/ executor emits SCOPE_EXCLUSION for all three scenarios — these old
      # strings are NOT emitted. S3-R14-C2-P and S3-R15-C2-P experiments that check
      # the old strings are sealed proof artifacts; do not retroactively update them.
      # Phase 2 migration: remove this constant once all non-experiment callers are
      # verified to use ReasonCode::SCOPE_EXCLUSION or "runtime.temporal_scope_exclusion".
      LEGACY_ALIASES = {
        "runtime.non_temporal_not_covered" => SCOPE_EXCLUSION,
        "runtime.temporal_executor_bihistory_excluded" => SCOPE_EXCLUSION,
        "runtime.temporal_executor_core_refusal" => SCOPE_EXCLUSION
      }.freeze
    end

    # Phase1 — proof-local History[T] valid_time executor.
    #
    # Responsibilities:
    #   - Enforce approval_token before gate_state (AT-4/AT-5 order)
    #   - Validate authority_ref exactly against GATE3_AUTHORITY_REF (AT-9)
    #   - Enforce scope, cache-key, BiHistory, and CORE fragment guards
    #   - Emit temporal_live_read_observation unconditionally (AT-10)
    #   - Compose one CompatibilityReport-shaped hash per evaluation (AT-2)
    #   - Guarantee operation_check flags false for all blocked paths
    #
    # NOT responsible for: artifact loading, full CompatibilityReport composition
    # pipeline, Ledger binding, production cache, production signing.
    class Phase1
      # Proof-local only. In-memory, not durable. Not an audit receipt.
      # AT-10 emission is unconditional; persistence is deferred (see compatibility-report-persistence-audit-v0).
      attr_reader :observations, :last_compatibility_report

      # gate3_authorized: caller honor-system. Pass true only when a valid Architect
      # decision (gate3-live-read-decision-addendum-v0) authorizes non-proof live reads.
      # The lib/ class cannot verify the addendum exists; the caller is responsible.
      # Default false = live reads blocked at construction regardless of backend or token.
      def initialize(backend:, gate3_authorized: false)
        @backend          = backend
        @gate3_authorized = gate3_authorized
        @backend_identity_check = check_backend_identity(backend)
        @observations     = []
        @last_compatibility_report = nil
      end

      # Evaluate a temporal contract.
      #
      # contract: assembled contract Hash (fragment_class, temporal_nodes, contract_id)
      # token:    ExecutorApprovalToken Hash
      # inputs:   Hash of contract input values
      # as_of:    ISO8601 datetime string
      # requested_cache_key_fragment: expected "TEMPORAL" for Phase 1
      #
      # Returns a result Hash; never raises for guard failures.
      def evaluate(contract, token:, inputs:, as_of:, requested_cache_key_fragment: "TEMPORAL")
        contract_id = contract.fetch("contract_id")

        # Step 1: approval_token (AT-4 + AT-9) — must fire before gate check
        token_check = check_approval_token(token, contract_id)
        if token_check[:blocked]
          return build_refusal(token_check, contract_id: contract_id, as_of: as_of,
                               blocked_stage: "approval_token",
                               gate_open: @gate3_authorized,
                               token_ok: false,
                               cache_key_fragment: requested_cache_key_fragment)
        end

        # Step 2: gate_state (AT-5) — independent of token
        unless @gate3_authorized
          gate_check = { blocked: true,
                         reason_code: ReasonCode::GATE3_CLOSED,
                         message: "Gate 3 is closed for TEMPORAL evaluation",
                         context: { "gate" => "tbackend_gate3" } }
          return build_refusal(gate_check, contract_id: contract_id, as_of: as_of,
                               blocked_stage: "gate_state",
                               gate_open: false,
                               token_ok: true,
                               cache_key_fragment: requested_cache_key_fragment)
        end

        # Step 2b: backend_identity — Phase 1 must not quietly bind Ledger
        if @backend_identity_check[:blocked]
          return build_refusal(@backend_identity_check, contract_id: contract_id, as_of: as_of,
                               blocked_stage: "backend_identity",
                               gate_open: true,
                               token_ok: true,
                               cache_key_fragment: requested_cache_key_fragment)
        end

        # Step 3: scope — TEMPORAL fragment only, before cache
        unless contract.fetch("fragment_class") == "temporal"
          scope_check = { blocked: true,
                          reason_code: ReasonCode::NON_TEMPORAL,
                          message: "Phase 1 executor handles only TEMPORAL fragment contracts",
                          context: { "expected_scope" => "history_valid_time",
                                     "actual_fragment" => contract.fetch("fragment_class"),
                                     "actual_surface" => contract.fetch("fragment_class") } }
          return build_refusal(scope_check, contract_id: contract_id, as_of: as_of,
                               blocked_stage: "scope",
                               gate_open: true,
                               token_ok: true,
                               cache_key_fragment: requested_cache_key_fragment)
        end

        # Step 4: cache_key schema (AT-6) — before any backend access
        unless requested_cache_key_fragment == "TEMPORAL"
          cache_check = { blocked: true,
                          reason_code: ReasonCode::CACHE_MISMATCH,
                          message: "TEMPORAL evaluation cannot use a #{requested_cache_key_fragment}-shaped cache key",
                          context: { "gate"               => "L-T5",
                                     "expected_fragment"  => "TEMPORAL",
                                     "requested_fragment" => requested_cache_key_fragment } }
          return build_refusal(cache_check, contract_id: contract_id, as_of: as_of,
                               blocked_stage: "cache_key",
                               gate_open: true,
                               token_ok: true,
                               cache_key_fragment: requested_cache_key_fragment)
        end

        # All preflight guards passed — compose report, run kernel
        report = compose_report(contract_id: contract_id, gate_open: true,
                                token_ok: true, cache_key_ok: true,
                                readiness: "ready")
        @last_compatibility_report = report

        kernel_result = run_execution_kernel(contract, inputs: inputs, as_of: as_of)
        kernel_result.merge("compatibility_report_id" => report.fetch("report_id"))
      end

      private

      # Phase 1 permits the proof-local MemoryBackend or an explicitly
      # identified non-Ledger backend. Ledger-backed adapters and wrappers that
      # invoke Ledger package code require a Phase 2 Architect addendum.
      def check_backend_identity(backend)
        class_name = backend.class.name.to_s
        if class_name == PHASE1_MEMORY_BACKEND_CLASS
          return { blocked: false,
                   backend_identity: { "kind" => "proof_local_memory_backend",
                                       "class_name" => class_name } }
        end

        unless backend.respond_to?(:phase1_backend_identity)
          return backend_identity_blocked(
            class_name,
            "backend must be MemoryBackend or expose phase1_backend_identity"
          )
        end

        identity = backend.phase1_backend_identity
        return backend_identity_blocked(class_name, "phase1_backend_identity must return Hash") unless identity.is_a?(Hash)

        phase1_allowed = identity_fetch(identity, "phase1_allowed") == true
        ledger_backed = identity_fetch(identity, "ledger_backed") == true
        invokes_ledger = identity_fetch(identity, "invokes_ledger_package") == true
        package_adapter = identity_fetch(identity, "package_adapter") == true
        family = identity_fetch(identity, "backend_family").to_s.downcase
        kind = identity_fetch(identity, "kind").to_s.downcase

        if phase1_allowed && !ledger_backed && !invokes_ledger && !package_adapter &&
           !ledger_family?(family) && !ledger_kind?(kind) && !ledger_like_class_name?(class_name)
          return { blocked: false, backend_identity: identity.merge("class_name" => class_name) }
        end

        backend_identity_blocked(
          class_name,
          "backend identity is not allowed for Phase 1",
          identity: identity
        )
      end

      def backend_identity_blocked(class_name, message, identity: nil)
        context = { "backend_class" => class_name }
        context["backend_identity"] = identity if identity
        { blocked: true,
          reason_code: ReasonCode::BACKEND_IDENTITY_BLOCKED,
          message: message,
          context: context }
      end

      def identity_fetch(identity, key)
        return identity[key] if identity.key?(key)

        symbol_key = key.to_sym
        return identity[symbol_key] if identity.key?(symbol_key)

        nil
      end

      def ledger_like_class_name?(class_name)
        class_name.split("::").any? do |part|
          part.start_with?("Ledger") || part == "IgniterLedger"
        end
      end

      def ledger_family?(family)
        family == "ledger" || family == "igniter-ledger" || family == "igniter_ledger"
      end

      def ledger_kind?(kind)
        kind == "ledger" || kind.start_with?("ledger_") || kind.start_with?("igniter_ledger")
      end

      def phase1_backend_scope_label
        identity = @backend_identity_check[:backend_identity] || {}
        backend_kind = identity["kind"] || "phase1_backend"
        "History[T].valid_time / #{backend_kind} / proof-local"
      end

      # AT-4 + AT-9: validate token structure and exact authority_ref match.
      # Returns { blocked: false } on success, or { blocked: true, reason_code:, message: } on failure.
      def check_approval_token(token, contract_id)
        return { blocked: true, reason_code: ReasonCode::APPROVAL_MISSING,
                 message: "approval token required" } unless token
        return { blocked: true, reason_code: ReasonCode::APPROVAL_MALFORMED,
                 message: "token must be Hash" } unless token.is_a?(Hash)

        unless token.fetch("kind", nil) == "executor_approval_token" &&
               token.fetch("version", nil) == "executor-approval-token-v1"
          return { blocked: true, reason_code: ReasonCode::APPROVAL_MALFORMED,
                   message: "token kind/version invalid" }
        end

        # AT-9: exact authority_ref match against Gate 3 decision record
        authority_ref = token.fetch("authority_ref", nil)
        if authority_ref.nil?
          return { blocked: true, reason_code: ReasonCode::APPROVAL_MALFORMED,
                   message: "missing authority_ref" }
        end
        unless authority_ref == GATE3_AUTHORITY_REF
          return { blocked: true, reason_code: ReasonCode::AUTHORITY_UNTRUSTED,
                   message: "authority_ref does not match Gate 3 decision record",
                   context: { "expected" => GATE3_AUTHORITY_REF, "got" => authority_ref } }
        end

        unless token.fetch("gate", nil) == "tbackend_gate3"
          return { blocked: true, reason_code: ReasonCode::APPROVAL_MALFORMED,
                   message: "token gate must be tbackend_gate3" }
        end

        { blocked: false }
      end

      # AT-12, AT-7, AT-10: execution kernel.
      # Only reached after all preflight guards pass.
      def run_execution_kernel(contract, inputs:, as_of:)
        contract_id = contract.fetch("contract_id")

        # AT-12: defense-in-depth — executor independently refuses non-TEMPORAL fragment
        unless contract.fetch("fragment_class") == "temporal"
          return { "kind"         => "evaluation_refusal",
                   "status"       => "blocked",
                   "guard_at"     => "temporal_executor_phase1_kernel",
                   "reason_code"  => ReasonCode::CORE_REFUSAL,
                   "contract_id"  => contract_id,
                   "context"      => { "expected_scope" => "history_valid_time",
                                       "actual_fragment" => contract.fetch("fragment_class"),
                                       "actual_surface" => contract.fetch("fragment_class") },
                   "gate"         => "AT-12" }
        end

        temporal_nodes = contract.fetch("temporal_nodes", [])
        access_nodes   = temporal_nodes.select { |n| n["kind"] == "temporal_access_node" }

        # AT-7: Phase 1 scope is valid_time only; BiHistory explicitly refused
        bihistory = access_nodes.select { |n| n["axis"] == "bitemporal" }
        if bihistory.any?
          return { "kind"        => "evaluation_refusal",
                   "status"      => "blocked",
                   "guard_at"    => "temporal_executor_phase1_kernel",
                   "reason_code" => ReasonCode::BIHISTORY_EXCLUDED,
                   "contract_id" => contract_id,
                   "context"     => { "expected_scope" => "history_valid_time",
                                      "actual_fragment" => "temporal",
                                      "actual_surface" => "bihistory",
                                      "actual_axis" => "bitemporal" },
                   "gate"        => "AT-7" }
        end

        temporal_inputs = temporal_nodes
          .select { |n| n["kind"] == "temporal_input_node" }
          .to_h { |n| [n.fetch("name"), n] }
        all_inputs = inputs.merge("as_of" => as_of)

        results = access_nodes.map do |node|
          evaluate_valid_time_node(node, temporal_inputs, all_inputs, contract_id)
        end

        { "status"               => "ok",
          "kind"                 => "temporal_evaluation_result",
          "contract_id"          => contract_id,
          "results"              => results,
          "observations_emitted" => @observations.length,
          "runtime_enforced"     => true,
          "scope"                => phase1_backend_scope_label,
          "excluded"             => "Ledger, BiHistory, stream, OLAP, writes, production_cache" }
      end

      def evaluate_valid_time_node(access_node, temporal_inputs, inputs, contract_id)
        source    = access_node.fetch("source_ref")
        template  = temporal_inputs.fetch(source).fetch("store_ref")
        as_of_ref = access_node["as_of_ref"] ||
                    access_node.dig("coordinate_refs", "as_of") ||
                    "as_of"
        subject = render_ref(template, inputs)
        as_of   = inputs.fetch(as_of_ref)

        result, backend_obs = @backend.read_as_of(subject, as_of)
        backend_identity = @backend_identity_check[:backend_identity] || {}

        # AT-10: unconditional observation per read — not gated on persistence readiness
        @observations << {
          "kind"                    => "temporal_live_read_observation",
          "contract_id"             => contract_id,
          "node"                    => access_node.fetch("name"),
          "axis"                    => "valid_time",
          "subject"                 => subject,
          "as_of"                   => as_of,
          "result_present"          => result.is_a?(Hash) && result["kind"] == "some",
          "backend_identity"         => backend_identity,
          "backend_observation_ref" => backend_obs.fetch("observation_id"),
          "persistence"             => "proof_local"
        }

        { "node" => access_node.fetch("name"), "axis" => "valid_time",
          "result" => result, "backend_observation" => backend_obs }
      end

      # Build a minimal CompatibilityReport-shaped hash for blocked paths.
      def build_refusal(check, contract_id:, as_of:, blocked_stage:,
                        gate_open:, token_ok:, cache_key_fragment:)
        report = compose_report(
          contract_id: contract_id, gate_open: gate_open,
          token_ok: token_ok, cache_key_ok: cache_key_fragment == "TEMPORAL",
          readiness: "blocked", blocked_reason_code: check[:reason_code]
        )
        @last_compatibility_report = report

        { "kind"                    => "evaluation_refusal",
          "status"                  => "blocked",
          "guard_at"                => "temporal_executor_phase1",
          "reason_code"             => check[:reason_code],
          "message"                 => check[:message],
          "contract_id"             => contract_id,
          "as_of"                   => as_of,
          "context"                 => check.fetch(:context, {}),
          "blocked_stage"           => blocked_stage,
          "compatibility_report_id" => report.fetch("report_id"),
          "operation_check"         => no_live_operations }
      end

      # AT-2: compose one CompatibilityReport-shaped hash per evaluation.
      # Single-report mode; split_fragments_allowed always false.
      def compose_report(contract_id:, gate_open:, token_ok:, cache_key_ok:, readiness:,
                         blocked_reason_code: nil)
        reason_code = readiness == "ready" ? ReasonCode::EVALUATION_READY : blocked_reason_code
        body = {
          "kind"           => "compatibility_report",
          "format_version" => PHASE1_FORMAT_VERSION,
          "contract_id"    => contract_id,
          "composition"    => {
            "mode"                  => "single_report",
            "single_report_required" => true,
            "split_fragments_allowed" => false
          },
          "runtime_gate_check" => {
            "gate"          => "tbackend_gate3",
            "decision"      => gate_open ? "open" : "closed",
            "authority_ref" => gate_open ? GATE3_AUTHORITY_REF : nil
          },
          "executor_approval_check" => {
            "decision"    => token_ok ? "ok" : "blocked",
            "reason_code" => token_ok ? "runtime.executor_approval_token_valid" : ReasonCode::APPROVAL_MISSING
          },
          "cache_key_check" => {
            "decision"    => cache_key_ok ? "ok" : "blocked",
            "fragment"    => cache_key_ok ? "TEMPORAL" : "other",
            "reason_code" => cache_key_ok ? "runtime.temporal_cache_key_valid" : ReasonCode::CACHE_MISMATCH
          },
          "evaluation_readiness" => {
            "decision"             => readiness,
            "reason_code"          => reason_code,
            "blocks_before_executor" => readiness != "ready"
          },
          "runtime_enforced" => gate_open && token_ok && cache_key_ok && readiness == "ready",
          "report_only"      => !(gate_open && token_ok && cache_key_ok && readiness == "ready"),
          "operation_check"  => no_live_operations
        }
        body.merge("report_id" => "compat/phase1/#{short_report_hash(body)}")
      end

      def no_live_operations
        { "temporal_executor_call_attempted" => false,
          "live_tbackend_call_attempted"     => false,
          "ledger_call_attempted"            => false,
          "temporal_read_attempted"          => false,
          "cache_call_attempted"             => false }
      end

      def short_report_hash(value)
        Digest::SHA256.hexdigest(JSON.generate(canonical_normalize(value)))[0, 16]
      end

      def canonical_normalize(value)
        case value
        when Hash  then value.keys.sort_by(&:to_s).each_with_object({}) { |k, h| h[k.to_s] = canonical_normalize(value[k]) }
        when Array then value.map { |v| canonical_normalize(v) }
        else            value
        end
      end

      def render_ref(template, inputs)
        template.gsub(/\{([^}]+)\}/) { inputs.fetch(Regexp.last_match(1)) }
      end
    end
  end
end
