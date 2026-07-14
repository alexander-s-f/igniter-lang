#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

# =============================================================================
# Igniter-Lang Minimal Parser
# Implements PROP-014 / PROP-015 grammar kernel.
# Outputs ParsedProgram JSON for acceptance testing.
#
# Grammar (subset):
#   SourceFile   := ModuleDecl? ImportDecl* TopDecl*
#   TopDecl      := ContractDecl | TypeDecl | FunctionDecl | OLAPPointDecl
#                 | AssumptionsDecl
#                 | TraitDecl | ImplDecl | ContractShapeDecl
#   ContractDecl := "contract" Name TypeParams? Implements? "{" BodyDecl* "}"
#   BodyDecl     := EscapeDecl | InputDecl | ReadDecl | ComputeDecl
#                 | SnapshotDecl | WindowDecl | OutputDecl
#   FunctionDecl := "def" Name "(" Params? ")" "->" TypeRef "{" Body "}"
#   TypeDecl     := "type" Name "{" FieldDecl* "}"
#   Expr         := Literal | Ref | BinOp | Call | FieldAccess
#                 | IfExpr | BlockExpr | Lambda | ArrayLit | RecordLit
# =============================================================================

module IgniterLang
  # ---------------------------------------------------------------------------
  # Token types
  # ---------------------------------------------------------------------------
  TOKEN_TYPES = %i[
    keyword ident string_lit int_lit float_lit bool_lit nil_lit
    symbol_lit lbrace rbrace lparen rparen lbracket rbracket
    dot dot_dot comma colon double_colon dot_dot_dot arrow fat_arrow left_arrow
    op assign pipe question bang
    newline eof comment illegal
  ].freeze

  Token = Struct.new(:type, :value, :line, :col)

  # ---------------------------------------------------------------------------
  # Lexer
  # ---------------------------------------------------------------------------
  KEYWORDS = %w[
    module import const contract contract_shape type def trait impl
    input output compute read snapshot window escape
    stream fold_stream
    assumptions assumption uses
    olap_point
    invariant predicate severity label message overridable_with
    from lifecycle using implements via
    profile authority
    pipeline step scoped_by cardinality schema_version tenant_free
    if else let
    true false nil
    and or not
    for loop recursive fuel_bounded decreases
    lead
    size_relation
    variant match
    intent
  ].freeze

  class Lexer
    def initialize(source)
      @source = source
      @pos    = 0
      @line   = 1
      @col    = 1
      @tokens = []
    end

    def tokenize
      until @pos >= @source.length
        skip_whitespace_and_comments
        break if @pos >= @source.length

        tok = next_token
        @tokens << tok if tok && tok.type != :comment
      end
      @tokens << Token.new(:eof, nil, @line, @col)
      @tokens
    end

    private

    def peek(offset = 0) = @source[@pos + offset]
    def advance
      ch = @source[@pos]
      @pos += 1
      if ch == "\n"
        @line += 1
        @col = 1
      else
        @col += 1
      end
      ch
    end

    def skip_whitespace_and_comments
      loop do
        # skip whitespace
        while @pos < @source.length && @source[@pos] =~ /[ \t\r\n]/
          advance
        end
        # skip -- line comments
        if @pos + 1 < @source.length && @source[@pos] == "-" && @source[@pos + 1] == "-"
          while @pos < @source.length && @source[@pos] != "\n"
            advance
          end
        else
          break
        end
      end
    end

    def next_token
      l, c = @line, @col
      ch = peek

      case ch
      when '"' then read_string(l, c)
      when /[0-9]/ then read_number(l, c)
      when ":" then read_symbol_or_colon(l, c)
      when "-"
        if peek(1) == ">"
          advance; advance
          Token.new(:arrow, "->", l, c)
        else
          advance
          Token.new(:op, "-", l, c)
        end
      when "+"
        if peek(1) == "+"
          advance; advance
          Token.new(:op, "++", l, c)
        else
          advance
          Token.new(:op, "+", l, c)
        end
      when "*" then advance; Token.new(:op, "*", l, c)
      when "/" then advance; Token.new(:op, "/", l, c)
      when "=" then
        if peek(1) == "="
          advance; advance; Token.new(:op, "==", l, c)
        elsif peek(1) == ">"
          advance; advance; Token.new(:fat_arrow, "=>", l, c)  # PROP-044-P3
        else
          advance; Token.new(:assign, "=", l, c)
        end
      when "!" then
        if peek(1) == "="
          advance; advance; Token.new(:op, "!=", l, c)
        else
          advance; Token.new(:bang, "!", l, c)
        end
      when "<" then
        if peek(1) == "="
          advance; advance; Token.new(:op, "<=", l, c)
        elsif peek(1) == "-"
          # LANG-CH13-WRITE-EVIDENCE-P60: `write store <- value` append operator.
          advance; advance; Token.new(:left_arrow, "<-", l, c)
        else
          advance; Token.new(:op, "<", l, c)
        end
      when ">" then
        if peek(1) == "="
          advance; advance; Token.new(:op, ">=", l, c)
        else
          advance; Token.new(:op, ">", l, c)
        end
      when "&" then
        if peek(1) == "&"
          advance; advance; Token.new(:op, "&&", l, c)
        else
          advance; Token.new(:op, "&", l, c)
        end
      when "|" then
        if peek(1) == "|"
          advance; advance; Token.new(:op, "||", l, c)
        else
          advance; Token.new(:pipe, "|", l, c)
        end
      when "{" then advance; Token.new(:lbrace, "{", l, c)
      when "}" then advance; Token.new(:rbrace, "}", l, c)
      when "(" then advance; Token.new(:lparen, "(", l, c)
      when ")" then advance; Token.new(:rparen, ")", l, c)
      when "[" then advance; Token.new(:lbracket, "[", l, c)
      when "]" then advance; Token.new(:rbracket, "]", l, c)
      when "." then
        if peek(1) == "."
          advance; advance
          Token.new(:dot_dot, "..", l, c)
        else
          advance; Token.new(:dot, ".", l, c)
        end
      when "," then advance; Token.new(:comma, ",", l, c)
      when "@" then advance; Token.new(:at, "@", l, c)
      # LANG-OPTIONAL-FIELD-PARTIAL-RECORD-P3: emit `?` so parse_type_decl's existing
      # :question branch (optional field marker `f : T?`) actually fires. This is
      # CAPTURE, not activation — the optional flag is inert unless the TypeChecker
      # is constructed with `optional_fields: true` (gate default OFF).
      when "?" then advance; Token.new(:question, "?", l, c)
      when /[a-zA-Z_]/ then read_ident_or_keyword(l, c)
      else
        advance
        nil
      end
    end

    # LANG-RUBY-STRING-ESCAPES-PARITY-P2: decode the same minimal conventional escape
    # set the Rust lexer already decodes (`\"` `\\` `\n` `\t` `\r`; see igniter-compiler
    # src/lexer.rs `read_string`, LAB-LANG-STRING-ESCAPES-P1). An invalid escape or an
    # unterminated string (including a trailing backslash at EOF) returns an `:illegal`
    # token carrying the reason in `value` — mirrors Rust's `Illegal` token exactly, so
    # the parser can surface it as a bounded `OOF-LEX1` diagnostic instead of silently
    # mis-tokenizing (the old loop here read a `\` as a literal char and let the NEXT
    # `"` close the string, desyncing every following token — see mesh_net_io.ig repro
    # in lang-ruby-string-escapes-parity-p2-v0.md). Ordinary escape-free strings are
    # byte-for-byte unchanged.
    def read_string(l, c)
      advance # consume opening "
      buf = +""
      loop do
        if @pos >= @source.length
          return Token.new(:illegal, "unterminated string literal", l, c)
        end
        ch = peek
        case ch
        when '"'
          advance # consume closing "
          return Token.new(:string_lit, buf, l, c)
        when "\\"
          advance # consume the backslash
          if @pos >= @source.length
            return Token.new(:illegal, "unterminated string literal (trailing backslash)", l, c)
          end
          esc = peek
          decoded = case esc
                    when '"'  then '"'
                    when "\\" then "\\"
                    when "n"  then "\n"
                    when "t"  then "\t"
                    when "r"  then "\r"
                    else
                      return Token.new(:illegal, "invalid string escape: \\#{esc}", l, c)
                    end
          advance # consume the escape char
          buf << decoded
        else
          buf << advance
        end
      end
    end

    def read_number(l, c)
      buf = +""
      while @pos < @source.length && peek =~ /[0-9]/
        buf << advance
      end
      if peek == "." && @source[@pos + 1] =~ /[0-9]/
        buf << advance
        while @pos < @source.length && peek =~ /[0-9]/
          buf << advance
        end
        Token.new(:float_lit, buf.to_f, l, c)
      else
        Token.new(:int_lit, buf.to_i, l, c)
      end
    end

    def read_symbol_or_colon(l, c)
      advance # consume ':'
      if peek =~ /[a-zA-Z_]/
        buf = +""
        while @pos < @source.length && peek =~ /[a-zA-Z0-9_]/
          buf << advance
        end
        Token.new(:symbol_lit, buf, l, c)
      else
        Token.new(:colon, ":", l, c)
      end
    end

    def read_ident_or_keyword(l, c)
      buf = +""
      while @pos < @source.length && peek =~ /[a-zA-Z0-9_.]/
        # Stop at '..' or '.' followed by non-alpha (module path separator only)
        if peek == "."
          break unless @source[@pos + 1] =~ /[A-Z]/  # only Module.Name paths
        end
        buf << advance
      end
      type = KEYWORDS.include?(buf) ? :keyword : :ident
      # bool literals
      type = :bool_lit if %w[true false].include?(buf)
      type = :nil_lit  if buf == "nil"
      Token.new(type, buf, l, c)
    end
  end

  # ---------------------------------------------------------------------------
  # Parser — recursive descent
  # ---------------------------------------------------------------------------
  class ParseError < StandardError
    attr_reader :line, :col
    def initialize(msg, line = nil, col = nil)
      super(msg)
      @line = line
      @col  = col
    end
  end

  class Parser
    def initialize(tokens)
      @tokens = tokens
      @pos    = 0
      @errors = []
    end

    def parse
      program = { "kind" => "source_file", "module" => nil, "imports" => [],
                  "traits" => [], "impls" => [], "contract_shapes" => [],
                  "contracts" => [], "types" => [], "variants" => [],  # PROP-044-P3
                  "functions" => [], "consts" => [],
                  "pipelines" => [], "olap_points" => [], "assumptions" => [],
                  "entrypoint" => nil, # PROP-ENTRYPOINT-P3
                  "profiles" => [],        # PROP-040
                  "size_relations" => [],  # PROP-041
                  "parse_errors" => [] }

      # optional module declaration
      if peek_kw?("module")
        advance
        program["module"] = parse_module_path
      end

      # PROP-045: optional module-level intent descriptor (after module, before imports)
      if peek_kw?("intent")
        advance
        tok = peek
        if peek_type?(:string_lit)
          program["intent_text"] = advance.value
        else
          @errors << { "message" => "intent requires a string literal", "line" => tok.line }
        end
      end

      # imports
      while peek_kw?("import")
        advance
        program["imports"] << parse_import
      end

      # top-level declarations
      #
      # LANG-RUBY-STRING-ESCAPES-PARITY-P2: `parse_top_decl` can raise `ParseError` from a
      # nested `expect_type!`/`expect_kw!`/`expect_value!` with no local rescue (e.g. an
      # `:illegal` string-escape token — invalid escape / trailing backslash / unterminated
      # string — that swallows the rest of the source to EOF, so the enclosing `expect_type!
      # (:rbrace)` finds EOF instead). Rust's `pub fn parse(&mut self) -> SourceFile` NEVER
      # raises: its top-level loop is `match self.parse_top_decl() { Ok(..) => .., _ =>
      # self.advance() }`, so any parse error anywhere always resolves to a recorded
      # diagnostic plus one-token resync, never a panic (src/parser.rs `parse`, ~line 1039).
      # This rescue is the Ruby-side mirror of that same guarantee — it does not change
      # what a WELL-FORMED program parses to (no local rescue existed here before because
      # none was needed), it only stops a malformed one from raising past `Parser#parse`.
      # `|| peek.nil?` guards a case `expect_type!`/friends already exhibited before this
      # rescue existed (see the sibling LANG-RUBY-VARIANT-MATCH-PARSER-P1 note on
      # `parse_primary`'s catch-all): those helpers `advance` the eof sentinel itself
      # before raising, so by the time the rescue below runs `peek` may already be past
      # the token array's end (nil) rather than sitting on `:eof` — treat both as "done".
      until peek_type?(:eof) || peek.nil?
        decl =
          begin
            parse_top_decl
          rescue ParseError => e
            @errors << { "message" => e.message, "line" => e.line, "col" => e.col }
            advance if peek && !peek_type?(:eof)
            nil
          end
        case decl&.fetch("kind")
        when "trait"          then program["traits"]          << decl
        when "impl"           then program["impls"]           << decl
        when "contract_shape" then program["contract_shapes"] << decl
        when "contract"       then program["contracts"]       << decl
        when "type"           then program["types"]           << decl
        when "const"          then program["consts"]          << decl
        when "variant"        then program["variants"]        << decl  # PROP-044-P3
        when "function"       then program["functions"]       << decl
        when "pipeline"       then program["pipelines"]       << decl
        when "olap_point"     then program["olap_points"]     << decl
        when "assumptions"    then program["assumptions"].concat(decl.fetch("assumptions", []))
        when "entrypoint"
          if program["entrypoint"]
            @errors << {
              "rule" => "OOF-EP1",
              "severity" => "error",
              "message" => "Duplicate entrypoint declaration: #{decl.fetch("target")}",
              "token" => decl.fetch("target"),
              "line" => decl.dig("source_span", "line"),
              "col" => decl.dig("source_span", "col")
            }
          else
            program["entrypoint"] = decl
          end
        when "profile"        then program["profiles"]        << decl  # PROP-040
        when "size_relation"  then program["size_relations"]  << decl  # PROP-041
        end
      end

      program["parse_errors"] = @errors
      program
    end

    private

    # ---- Token navigation --------------------------------------------------

    def peek(offset = 0) = @tokens[@pos + offset]
    def current          = @tokens[@pos]
    def advance          = @tokens[@pos].tap { @pos += 1 }

    def peek_type?(type)     = peek&.type == type
    def peek_value?(val)     = peek&.value == val
    def peek_kw?(kw)         = peek&.type == :keyword && peek&.value == kw
    def peek_ident?          = peek&.type == :ident
    def peek_symbol?(name)   = peek&.type == :symbol_lit && peek&.value == name

    def expect_type!(type)
      tok = advance
      raise ParseError.new("Expected #{type}, got #{tok.type}(#{tok.value})", tok.line, tok.col) unless tok.type == type
      tok
    end

    def expect_kw!(kw)
      tok = advance
      raise ParseError.new("Expected keyword '#{kw}', got #{tok.value}", tok.line, tok.col) unless tok.value == kw
      tok
    end

    def expect_value!(val)
      tok = advance
      raise ParseError.new("Expected '#{val}', got #{tok.value}", tok.line, tok.col) unless tok.value == val
      tok
    end

    def name_token!(types = %i[ident keyword])
      tok = peek
      raise ParseError.new("Expected name, got #{tok.type}(#{tok.value})", tok.line, tok.col) unless types.include?(tok.type)
      advance.value
    end

    # ---- Module / Import ---------------------------------------------------

    def parse_module_path
      parts = []
      parts << name_token!(%i[ident])
      while peek_type?(:dot)
        advance
        parts << name_token!(%i[ident])
      end
      parts.join(".")
    end

    def parse_import
      path_parts = []
      path_parts << name_token!(%i[ident])
      names = nil
      loop do
        if peek_type?(:dot) && peek(1)&.type == :lbrace
          advance; advance
          names = []
          until peek_type?(:rbrace)
            names << name_token!(%i[ident])
            advance if peek_type?(:comma)
          end
          expect_type!(:rbrace)
          break
        elsif peek_type?(:dot) && peek(1)&.type == :ident
          advance
          path_parts << name_token!(%i[ident])
        else
          break
        end
      end
      { "module_path" => path_parts.join("."), "names" => names }
    end

    # ---- Top-level declarations --------------------------------------------

    # `convergent` (Ch13 ConvergentLoop, PROP-050/P46) is the 4th local loop-class
    # modifier — it repeats while driving a metric toward a threshold, terminating
    # on convergence OR fuel exhaustion. It sits alongside recursive/fuel_bounded.
    # `service` (Ch13 ServiceLoop, PROP-037 annex / P50) is the 5th loop class —
    # a non-terminating, liveness-governed loop. v0 is a DECLARATION slice: the
    # `service` modifier + obligation clauses are checked for presence only; the
    # form is a modifier for parser-parity (ch13 §13.8 "distinct form" prose is
    # updated at impl — see P49 ⚑). Runtime liveness stays HELD (PROP-037).
    CONTRACT_MODIFIERS = %w[pure observed effect privileged irreversible recursive fuel_bounded convergent service].freeze
    # ConvergentLoop `on_exhaustion :<action>` — v0 actions (Ch13 §13.1).
    ON_EXHAUSTION_ACTIONS = %w[return_partial suspend].freeze
    # ServiceLoop `cancellation <mode>` — v0 modes (ch11 §11.3).
    CANCELLATION_MODES = %w[required optional none].freeze

    def parse_top_decl
      tok = peek
      case tok.value
      when "trait"          then advance; parse_trait_decl
      when "impl"           then advance; parse_impl_decl
      when "contract_shape" then advance; parse_contract_shape_decl
      when "contract"       then advance; parse_contract_decl
      when *CONTRACT_MODIFIERS
        modifier = tok.value
        advance
        if peek.value == "contract"
          advance
          parse_contract_decl(modifier: modifier)
        else
          @errors << { "message" => "Expected 'contract' after modifier '#{modifier}'", "line" => tok.line }
          nil
        end
      when "type"           then advance; parse_type_decl
      when "const"          then advance; parse_const_decl
      when "variant"        then advance; parse_variant_decl    # PROP-044-P3
      when "def"            then advance; parse_function_decl
      when "pipeline"       then advance; parse_pipeline_decl
      when "olap_point"     then advance; parse_olap_point_decl
      when "assumptions"    then advance; parse_assumptions_block
      when "entrypoint"     then parse_entrypoint_decl
      when "profile"        then advance; parse_profile_decl         # PROP-040
      when "size_relation"  then advance; parse_size_relation_decl   # PROP-041
      else
        @errors << { "message" => "Unexpected token: #{tok.value}", "line" => tok.line }
        advance
        nil
      end
    end

    # LANG-MODULE-CONST-PROP-P3: deliberately strict literal-only subgrammar.
    def parse_const_decl
      name = name_token!(%i[ident])
      expect_type!(:colon)
      type_annotation = parse_type_ref
      expect_type!(:assign)
      { "kind" => "const", "name" => name, "type_annotation" => type_annotation,
        "expr" => parse_const_expr }
    rescue ParseError => e
      @errors << { "rule" => "OOF-CONST-LITERAL", "severity" => "error",
                   "message" => e.message, "line" => e.line, "col" => e.col }
      { "kind" => "const", "name" => (name || "<invalid>"),
        "type_annotation" => type_annotation, "expr" => { "kind" => "error" } }
    end

    def parse_const_expr
      tok = peek
      case tok.type
      when :int_lit
        advance; { "kind" => "literal", "value" => tok.value, "type_tag" => "Integer" }
      when :float_lit
        advance; { "kind" => "literal", "value" => tok.value, "type_tag" => "Float" }
      when :string_lit
        advance; { "kind" => "literal", "value" => tok.value, "type_tag" => "String" }
      when :bool_lit
        advance; { "kind" => "literal", "value" => tok.value == "true", "type_tag" => "Bool" }
      when :ident
        advance
        if peek_type?(:lparen) || peek_type?(:lbrace)
          raise ParseError.new("const RHS reference cannot be called or constructed", tok.line, tok.col)
        end
        { "kind" => "ref", "name" => tok.value }
      when :lbracket
        advance
        items = []
        until peek_type?(:rbracket) || peek_type?(:eof)
          items << parse_const_expr
          break unless peek_type?(:comma)
          advance
        end
        expect_type!(:rbracket)
        { "kind" => "array_literal", "items" => items }
      when :lbrace
        advance
        fields = {}
        until peek_type?(:rbrace) || peek_type?(:eof)
          key = name_token!(%i[ident keyword])
          expect_type!(:colon)
          fields[key] = parse_const_expr
          break unless peek_type?(:comma)
          advance
        end
        expect_type!(:rbrace)
        { "kind" => "record_literal", "fields" => fields }
      else
        raise ParseError.new("const RHS must be a scalar, record, array, or const reference", tok.line, tok.col)
      end
    end

    def parse_entrypoint_decl
      tok = advance
      target_tok = peek
      unless target_tok && %i[ident keyword].include?(target_tok.type)
        add_parse_error(
          rule: "OOF-EP2",
          message: "entrypoint declaration requires a contract target",
          token: target_tok&.value.to_s,
          line: tok.line,
          col: tok.col
        )
        return { "kind" => "entrypoint", "target" => "", "qualified" => false,
                 "source_span" => { "line" => tok.line, "col" => tok.col } }
      end

      target = parse_entrypoint_target
      if peek && !peek_type?(:eof) && peek.line == tok.line
        add_parse_error(
          rule: "OOF-P0",
          message: "Malformed entrypoint declaration after target '#{target}'",
          token: peek.value.to_s,
          line: peek.line,
          col: peek.col
        )
        skip_same_line(tok.line)
      end

      {
        "kind" => "entrypoint",
        "target" => target,
        "qualified" => target.include?("."),
        "source_span" => { "line" => tok.line, "col" => tok.col }
      }
    end

    def parse_entrypoint_target
      parts = [name_token!(%i[ident keyword])]
      while peek_type?(:dot)
        advance
        parts << name_token!(%i[ident keyword])
      end
      parts.join(".")
    end

    def skip_same_line(line)
      advance while peek && !peek_type?(:eof) && peek.line == line
    end

    # LANG-PROFILE-IDEMPOTENCY-RETRY-P31 (PROP-048): legal `retry` profile values.
    RETRY_VALUES = %w[enabled disabled].freeze

    # LANG-PROFILE-LOOP-CLASS-P42 (PROP-048): the LIVE loop-class vocabulary a
    # profile `loop:` may name. `finite` (the `for` FiniteLoop) was wired in by
    # LANG-PROFILE-LOOP-CLASS-FINITE-P44 — it was live (parse_for_loop) but P42's
    # first cut omitted it. ch11's aspirational `finite_loop`/`convergent`/
    # `service` values remain Ch13 (Managed Recursion) target prose with no
    # compiler surface — they fail closed (OOF-PROF6) until Ch13 lands.
    LOOP_CLASS_VALUES = %w[none finite recursive fuel_bounded budgeted convergent service].freeze
    # LANG-PROFILE-SERVICE-OBLIGATIONS-P51 (ch11 §11.3): the three service-loop
    # obligation modes a profile may declare for `heartbeat`/`checkpoint`/
    # `cancellation`. `required` obligates a bound contract to declare that
    # obligation clause (OOF-PROF7); `optional`/`none` impose nothing.
    SERVICE_OBLIGATION_MODES = %w[required optional none].freeze
    # LANG-PROFILE-MAX-STEP-LATENCY-P52: duration unit -> milliseconds, for the
    # profile `max_step_latency` ceiling (parse validation + classifier
    # comparison). Singular and plural forms; an unrecognized unit fails closed.
    DURATION_UNITS_MS = {
      "ms" => 1, "millisecond" => 1, "milliseconds" => 1,
      "second" => 1_000, "seconds" => 1_000,
      "minute" => 60_000, "minutes" => 60_000,
      "hour" => 3_600_000, "hours" => 3_600_000
    }.freeze

    # PROP-040: profile declarations. PROP-048 adds the `retry`
    # (LANG-PROFILE-IDEMPOTENCY-RETRY-P31) and `max_reversibility`
    # (LANG-PROFILE-MAX-REVERSIBILITY-P32) policy fields; other unrecognized
    # fields still parse and are dropped as before (additive).
    def parse_profile_decl
      name = name_token!(%i[ident])
      expect_type!(:lbrace)
      authority = nil
      retry_val = nil
      max_rev   = nil
      allowed_effects = nil
      requires_authority = nil
      loop_class = nil
      service_obligations = {}
      max_step_latency = nil
      until peek_type?(:rbrace) || peek_type?(:eof)
        field_name = name_token!(%i[ident keyword])
        expect_type!(:colon)
        # LANG-PROFILE-ALLOWED-EFFECTS-P35: `allowed_effects` takes a bracketed
        # list value (all other profile fields are scalar `field: ident`).
        if field_name == "allowed_effects"
          allowed_effects = parse_allowed_effects_list(name)
          next
        end
        # LANG-PROFILE-REQUIRES-AUTHORITY-P41 (PROP-049): `requires_authority`
        # takes a bracketed list of bare role idents.
        if field_name == "requires_authority"
          requires_authority = parse_requires_authority_list(name)
          next
        end
        # LANG-PROFILE-MAX-STEP-LATENCY-P52: `max_step_latency: <int>.<unit>` —
        # a duration value (not an ident), so it needs its own parse.
        if field_name == "max_step_latency"
          max_step_latency = parse_profile_max_step_latency(name)
          next
        end
        val_tok    = peek
        field_val  = name_token!(%i[ident keyword])
        case field_name
        when "authority"
          authority = field_val
        when "retry"
          # PROP-048 retry policy field. Malformed value fails closed at parse
          # time with OOF-PROF6 (mirrors OOF-M11/M16); the field is NOT stored,
          # so no OOF-PROF4 fires on an already-refused profile.
          if RETRY_VALUES.include?(field_val)
            retry_val = field_val
          else
            add_parse_error(
              rule: "OOF-PROF6",
              message: "profile '#{name}' declares invalid 'retry: #{field_val}'; " \
                       "allowed: enabled | disabled",
              token: field_val.to_s,
              line: val_tok&.line || 0,
              col: val_tok&.col || 0
            )
          end
        when "max_reversibility"
          # PROP-048 max_reversibility ceiling. Value is a bare ch12 scale name
          # (no colon — profile field position). Malformed fails closed
          # (OOF-PROF6); field not stored, so no OOF-PROF5 on a refused profile.
          if REVERSIBILITY_VALUES.include?(field_val)
            max_rev = field_val
          else
            add_parse_error(
              rule: "OOF-PROF6",
              message: "profile '#{name}' declares invalid 'max_reversibility: #{field_val}'; " \
                       "allowed: #{REVERSIBILITY_VALUES.join(' | ')}",
              token: field_val.to_s,
              line: val_tok&.line || 0,
              col: val_tok&.col || 0
            )
          end
        when "loop"
          # LANG-PROFILE-LOOP-CLASS-P42 (PROP-048): permitted loop class. Value
          # is a LIVE loop-class name; ch11's aspirational finite_loop/convergent/
          # service (Ch13) fail closed (OOF-PROF6) with a pointer, since no
          # compiler surface backs them yet. Field not stored ⇒ no OOF-PROF3.
          if LOOP_CLASS_VALUES.include?(field_val)
            loop_class = field_val
          else
            add_parse_error(
              rule: "OOF-PROF6",
              message: "profile '#{name}' declares invalid 'loop: #{field_val}'; " \
                       "allowed live loop classes: #{LOOP_CLASS_VALUES.join(' | ')} " \
                       "(`finite_loop` is a ch11 aspirational spelling — use `finite`)",
              token: field_val.to_s,
              line: val_tok&.line || 0,
              col: val_tok&.col || 0
            )
          end
        when "heartbeat", "checkpoint", "cancellation"
          # LANG-PROFILE-SERVICE-OBLIGATIONS-P51 (ch11 §11.3): service-loop
          # obligation. `required` obligates a bound contract to declare the
          # matching obligation clause (OOF-PROF7); `optional`/`none` impose
          # nothing. Malformed mode fails closed (OOF-PROF6); field not stored.
          if SERVICE_OBLIGATION_MODES.include?(field_val)
            service_obligations[field_name] = field_val
          else
            add_parse_error(
              rule: "OOF-PROF6",
              message: "profile '#{name}' declares invalid '#{field_name}: #{field_val}'; " \
                       "allowed: #{SERVICE_OBLIGATION_MODES.join(' | ')}",
              token: field_val.to_s,
              line: val_tok&.line || 0,
              col: val_tok&.col || 0
            )
          end
        end
      end
      expect_type!(:rbrace)
      node = { "kind" => "profile", "name" => name, "authority" => authority }
      node["retry"] = retry_val if retry_val
      node["max_reversibility"] = max_rev if max_rev
      node["allowed_effects"] = allowed_effects if allowed_effects
      node["requires_authority"] = requires_authority if requires_authority
      node["loop"] = loop_class if loop_class
      node["service_obligations"] = service_obligations unless service_obligations.empty?
      node["max_step_latency"] = max_step_latency if max_step_latency
      node
    end

    # LANG-PROFILE-MAX-STEP-LATENCY-P52: parse a profile `max_step_latency`
    # value as `<int>.<unit>` with a KNOWN duration unit. Returns the raw string
    # (e.g. "10.seconds") for the classifier to normalize/compare, or fails
    # closed (OOF-PROF6, not stored) on a malformed / unknown-unit value. Uses
    # only peek-guarded advances (never raises).
    def parse_profile_max_step_latency(profile_name)
      tok = peek
      raw = nil
      if peek_type?(:int_lit)
        n = advance.value
        if peek_type?(:dot)
          advance
          if peek_type?(:ident)
            unit = advance.value
            return "#{n}.#{unit}" if DURATION_UNITS_MS.key?(unit)
            raw = "#{n}.#{unit}"
          else
            raw = "#{n}."
          end
        else
          raw = n.to_s
        end
      elsif tok
        raw = tok.value.to_s
        advance
      end
      add_parse_error(
        rule: "OOF-PROF6",
        message: "profile '#{profile_name}' declares invalid 'max_step_latency: #{raw}'; " \
                 "expected <int>.<unit> with unit in #{DURATION_UNITS_MS.keys.join(' | ')}",
        token: raw.to_s,
        line: tok&.line || 0,
        col: tok&.col || 0
      )
      nil
    end

    # LANG-PROFILE-REQUIRES-AUTHORITY-P41 (PROP-049): parse a profile
    # `requires_authority: [role, ...]` list. Each entry is a BARE role ident
    # (matching the ch12 `authority` clause's bare-role-ident form). A dotted
    # entry (`Billing.Operator`) fails closed at parse with OOF-PROF6 and is
    # dropped. Returns a list of role idents. NOTE: this check grants NOTHING at
    # runtime — it only obligates a source `authority` declaration (see PROP-049).
    def parse_requires_authority_list(profile_name)
      expect_type!(:lbracket)
      roles = []
      until peek_type?(:rbracket) || peek_type?(:eof)
        tok = peek
        raw = parse_qualified_ref
        if raw.include?(".")
          add_parse_error(
            rule: "OOF-PROF6",
            message: "profile '#{profile_name}' requires_authority role '#{raw}' must be a " \
                     "bare role ident (no dots)",
            token: raw.to_s,
            line: tok&.line || 0,
            col: tok&.col || 0
          )
        else
          roles << raw
        end
        advance if peek_type?(:comma)
      end
      expect_type!(:rbracket)
      roles
    end

    # LANG-PROFILE-ALLOWED-EFFECTS-P35 (PROP-048): parse a profile
    # `allowed_effects: [<scope>.<system>, ...]` list. Each entry is a
    # scope-prefixed qualified ref (`external.payment_gateway`); the first
    # segment is the affects scope, the remainder the allowed target prefix.
    # A malformed entry (scope not external/internal, or no system) fails closed
    # at parse with OOF-PROF6 and is dropped. Returns [{scope, target_prefix}].
    def parse_allowed_effects_list(profile_name)
      expect_type!(:lbracket)
      entries = []
      until peek_type?(:rbracket) || peek_type?(:eof)
        tok = peek
        raw = parse_qualified_ref
        scope, _dot, prefix = raw.partition(".")
        if %w[external internal].include?(scope) && !prefix.empty?
          entries << { "scope" => scope, "target_prefix" => prefix }
        else
          add_parse_error(
            rule: "OOF-PROF6",
            message: "profile '#{profile_name}' allowed_effects entry '#{raw}' must be " \
                     "'<external|internal>.<system>'",
            token: raw.to_s,
            line: tok&.line || 0,
            col: tok&.col || 0
          )
        end
        advance if peek_type?(:comma)
      end
      expect_type!(:rbracket)
      entries
    end

    # PROP-041: size_relation TypeName accessor
    # Module-level declaration; order-independent with respect to contract bodies.
    def parse_size_relation_decl
      type_name    = name_token!(%i[ident])
      accessor     = name_token!(%i[ident])
      { "kind" => "size_relation", "type" => type_name, "accessor" => accessor }
    end

    def parse_assumptions_block
      expect_type!(:lbrace)
      assumptions = []
      until peek_type?(:rbrace) || peek_type?(:eof)
        tok = peek
        if tok.value == "assumption"
          advance
          assumption = parse_assumption_decl(tok)
          assumptions << assumption if assumption
        else
          add_parse_error(
            rule: "OOF-P0",
            message: "Expected 'assumption' declaration inside assumptions block",
            token: tok.value.to_s,
            line: tok.line,
            col: tok.col
          )
          advance
        end
      end
      expect_type!(:rbrace)
      { "kind" => "assumptions", "assumptions" => assumptions }
    end

    def parse_assumption_decl(assumption_tok)
      unless peek_ident?
        add_parse_error(
          rule: "OOF-P28",
          message: "assumption declaration requires a name",
          token: peek&.value.to_s,
          line: assumption_tok.line,
          col: assumption_tok.col
        )
        skip_balanced_block if peek_type?(:lbrace)
        return nil
      end

      name = name_token!(%i[ident])
      expect_type!(:lbrace)
      fields = {}
      until peek_type?(:rbrace) || peek_type?(:eof)
        field_tok = peek
        field = name_token!(%i[ident keyword])
        fields[field] = parse_assumption_field_value(field, field_tok)
        advance if peek_type?(:comma)
      end
      expect_type!(:rbrace)
      { "kind" => "assumption_decl", "name" => name, "fields" => fields }
    end

    def parse_assumption_field_value(field, field_tok)
      advance if peek_type?(:colon)
      case field
      when "kind"
        if peek_type?(:symbol_lit)
          advance.value
        else
          add_parse_error(rule: "OOF-P0", message: "assumption kind requires a symbol literal", token: field, line: field_tok.line, col: field_tok.col)
          nil
        end
      when "statement", "source"
        parse_optional_string_assumption_field(field, field_tok)
      when "strength"
        parse_assumption_strength(field_tok)
      else
        add_parse_error(rule: "OOF-P0", message: "Unknown assumption field: #{field}", token: field, line: field_tok.line, col: field_tok.col)
        nil
      end
    end

    def parse_optional_string_assumption_field(field, field_tok)
      return advance.value if peek_type?(:string_lit)
      return nil if peek_type?(:nil_lit) && advance

      add_parse_error(
        rule: "OOF-P0",
        message: "assumption #{field} requires a string literal",
        token: field,
        line: field_tok.line,
        col: field_tok.col
      )
      nil
    end

    def parse_assumption_strength(field_tok)
      return advance.value if peek_type?(:float_lit) || peek_type?(:int_lit)

      add_parse_error(
        rule: "OOF-P0",
        message: "assumption strength requires a numeric literal",
        token: "strength",
        line: field_tok.line,
        col: field_tok.col
      )
      nil
    end

    def parse_pipeline_decl
      name_tok = peek
      name = name_token!(%i[ident])
      expect_type!(:lbracket)
      in_type  = parse_type_ref
      expect_type!(:comma)
      out_type = parse_type_ref
      expect_type!(:comma)
      err_type = parse_type_ref
      expect_type!(:rbracket)
      expect_type!(:lbrace)
      steps = []
      until peek_type?(:rbrace) || peek_type?(:eof)
        if peek_kw?("step")
          advance
          steps << parse_step_decl
        else
          tok = peek
          @errors << { "message" => "Expected 'step', got #{tok.value}", "line" => tok.line }
          advance
        end
      end
      if steps.empty?
        add_parse_error(
          rule: "OOF-PG1",
          message: "pipeline must contain at least one step",
          token: name,
          line: name_tok.line,
          col: name_tok.col
        )
      end
      expect_type!(:rbrace)
      { "kind" => "pipeline", "name" => name,
        "in_type" => in_type, "out_type" => out_type, "err_type" => err_type,
        "steps" => steps }
    end

    def parse_olap_point_decl
      name_tok = peek
      name = name_token!(%i[ident])
      expect_type!(:lbrace)
      dimensions = {}
      measure = nil
      granularity = {}
      source = nil
      indexed = []

      until peek_type?(:rbrace) || peek_type?(:eof)
        clause_tok = peek
        clause = name_token!(%i[ident keyword])
        expect_type!(:colon)

        case clause
        when "dimensions"
          dimensions = parse_olap_type_map
        when "measure"
          measure = parse_type_ref
        when "granularity"
          granularity = parse_olap_symbol_map
        when "source"
          source = parse_olap_source_expr
        when "indexed"
          indexed = parse_olap_symbol_list
        else
          add_parse_error(
            rule: "OOF-P0",
            message: "Unknown olap_point clause: #{clause}",
            token: clause,
            line: clause_tok.line,
            col: clause_tok.col
          )
          skip_until_olap_clause_boundary
        end
      end

      add_parse_error(
        rule: "OOF-P0",
        message: "olap_point '#{name}' must declare dimensions",
        token: name,
        line: name_tok.line,
        col: name_tok.col
      ) if dimensions.empty?

      add_parse_error(
        rule: "OOF-P0",
        message: "olap_point '#{name}' must declare measure",
        token: name,
        line: name_tok.line,
        col: name_tok.col
      ) if measure.nil?

      expect_type!(:rbrace)
      {
        "kind" => "olap_point",
        "name" => name,
        "dimensions" => dimensions,
        "measure" => measure,
        "granularity" => granularity,
        "source" => source,
        "indexed" => indexed
      }
    end

    def parse_olap_type_map
      expect_type!(:lbrace)
      dims = {}
      until peek_type?(:rbrace) || peek_type?(:eof)
        dim = name_token!(%i[ident keyword])
        expect_type!(:colon)
        dims[dim] = parse_type_ref
        advance if peek_type?(:comma)
      end
      expect_type!(:rbrace)
      dims
    end

    def parse_olap_symbol_map
      expect_type!(:lbrace)
      values = {}
      until peek_type?(:rbrace) || peek_type?(:eof)
        key = name_token!(%i[ident keyword])
        expect_type!(:colon)
        values[key] = parse_olap_symbol_value
        advance if peek_type?(:comma)
      end
      expect_type!(:rbrace)
      values
    end

    def parse_olap_symbol_list
      expect_type!(:lbracket)
      values = []
      until peek_type?(:rbracket) || peek_type?(:eof)
        values << parse_olap_symbol_value
        advance if peek_type?(:comma)
      end
      expect_type!(:rbracket)
      values
    end

    def parse_olap_symbol_value
      if peek_type?(:symbol_lit)
        advance.value
      else
        name_token!(%i[ident keyword])
      end
    end

    def parse_olap_source_expr
      tokens = []
      depth = 0
      until peek_type?(:eof)
        break if depth.zero? && (peek_type?(:rbrace) || olap_clause_boundary?(peek, peek(1)))

        tok = advance
        depth += 1 if %i[lbrace lparen lbracket].include?(tok.type)
        depth -= 1 if %i[rbrace rparen rbracket].include?(tok.type)
        tokens << tok
      end
      return nil if tokens.empty?

      { "kind" => "raw_expr", "tokens" => tokens.map { |tok| tok.value.to_s } }
    end

    def parse_step_decl
      name_tok = peek
      name = name_token!(%i[ident])
      unless peek_type?(:colon)
        add_parse_error(
          rule: "OOF-PG2",
          message: "step must reference a contract",
          token: name,
          line: name_tok.line,
          col: name_tok.col
        )
        skip_optional_block_or_step_tail
        return { "kind" => "step", "name" => name, "ref" => nil }
      end

      expect_type!(:colon)
      ref  = parse_qualified_ref
      { "kind" => "step", "name" => name, "ref" => ref }
    end

    def parse_contract_decl(modifier: nil)
      name = name_token!(%i[ident])
      type_params = peek_type?(:lbracket) ? parse_contract_type_params : []
      implements = peek_kw?("implements") ? parse_implements_clause : nil
      # PROP-033: optional "via <profile_name>" clause before the body brace
      via_profile = peek_kw?("via") ? (advance; name_token!(%i[ident])) : nil
      expect_type!(:lbrace)
      body = []
      until peek_type?(:rbrace) || peek_type?(:eof)
        body << parse_body_decl
      end
      expect_type!(:rbrace)
      node = { "kind" => "contract", "name" => name, "modifier" => modifier || "pure", "type_params" => type_params }
      node["implements"] = implements if implements
      node["via_profile"] = via_profile if via_profile  # PROP-033
      node["body"] = body.compact
      node
    end

    def parse_trait_decl
      name = name_token!(%i[ident])
      type_params = peek_type?(:lbracket) ? parse_simple_type_params : []
      expect_type!(:lbrace)
      methods = []
      until peek_type?(:rbrace) || peek_type?(:eof)
        expect_kw!("def")
        methods << parse_trait_method
      end
      expect_type!(:rbrace)
      { "kind" => "trait", "name" => name, "type_params" => type_params, "methods" => methods }
    end

    def parse_trait_method
      name = name_token!(%i[ident])
      params = parse_params
      expect_type!(:arrow)
      return_type = parse_type_ref
      { "kind" => "trait_method", "name" => name, "params" => params, "return_type" => return_type }
    end

    def parse_impl_decl
      trait_ref = parse_type_ref_node
      expect_kw!("using")
      {
        "kind" => "impl",
        "trait_ref" => trait_ref,
        "using" => { "kind" => "qualified_ref", "name" => parse_qualified_ref }
      }
    end

    def parse_contract_shape_decl
      name = name_token!(%i[ident])
      type_params = peek_type?(:lbracket) ? parse_simple_type_params : []
      expect_type!(:lbrace)
      body = []
      until peek_type?(:rbrace) || peek_type?(:eof)
        tok = peek
        case tok.value
        when "input"  then advance; body << parse_input_decl
        when "output" then advance; body << parse_output_decl
        else
          @errors << { "message" => "Unknown contract_shape declaration: #{tok.value}", "line" => tok.line }
          advance
        end
      end
      expect_type!(:rbrace)
      { "kind" => "contract_shape", "name" => name, "type_params" => type_params, "body" => body.compact }
    end

    def parse_body_decl
      tok = peek
      case tok.value
      when "input"    then advance; parse_input_decl
      when "output"   then advance; parse_output_decl
      when "compute"  then advance; parse_compute_decl
      when "read"     then advance; parse_read_decl
      when "snapshot" then advance; parse_snapshot_decl
      when "window"   then advance; parse_window_decl
      when "escape"      then advance; parse_escape_decl
      when "capability"  then advance; parse_capability_decl
      when "effect"      then advance; parse_effect_binding_decl
      # LANG-EFFECT-SURFACE-RECEIPT-FAILURE-P1: Effect Surface metadata clauses
      when "receipt"     then advance; parse_receipt_decl
      when "failure"     then advance; parse_failure_decl
      # LANG-EFFECT-SURFACE-IDEMPOTENCY-P2: idempotency clause
      when "idempotency" then advance; parse_idempotency_decl
      # LANG-EFFECT-SURFACE-AFFECTS-P5: affects clause
      when "affects"     then advance; parse_affects_decl
      # LANG-CH13-WRITE-EVIDENCE-P60 (§13.6): `write store <- value evidence [refs]`
      when "write"       then advance; parse_write_decl
      # PROP-050 / LANG-EFFECT-CALL-NATURAL-SUGAR-P1: `invoke <name> = Callee(args...) using <cap>[, <cap>]*`
      when "invoke"      then advance; parse_invoke_decl
      # LANG-EFFECT-SURFACE-COMPENSATION-P22: compensation clauses
      when "compensation"    then advance; parse_compensation_decl
      when "no_compensation" then advance; { "kind" => "no_compensation" }
      # LANG-EFFECT-SURFACE-REVERSIBILITY-P25: reversibility clause
      when "reversibility"   then advance; parse_reversibility_decl
      # LANG-EFFECT-SURFACE-AUTHORITY-PARSER-P10: authority clause (declared intent only)
      when "authority"   then advance; parse_authority_decl
      when "stream"      then advance; parse_stream_decl
      when "fold_stream" then advance; parse_fold_stream_decl
      when "invariant"   then advance; parse_invariant_decl
      when "uses"        then advance; parse_uses_decl
      # PROP-039: loop and recursion body declarations
      when "for"         then advance; parse_for_loop
      when "loop"        then advance; parse_budgeted_loop
      when "decreases"   then advance; parse_decreases_decl
      when "max_steps"   then advance; parse_max_steps_decl
      # PROP-050/P46: ConvergentLoop obligation clauses (`convergent` contracts)
      when "variant"       then advance; parse_convergence_variant_decl
      when "convergence"   then advance; parse_convergence_decl
      when "on_exhaustion" then advance; parse_on_exhaustion_decl
      # PROP-037 annex/P50: ServiceLoop obligation clauses (`service` contracts)
      when "heartbeat"        then advance; parse_heartbeat_decl
      when "checkpoint"       then advance; parse_checkpoint_decl
      when "cancellation"     then advance; parse_cancellation_decl
      when "max_step_latency" then advance; parse_max_step_latency_decl
      # PROP-039 gate 8: loop body declarations (valid inside loop body only; TypeChecker rejects at contract level)
      when "lead"        then advance; parse_lead_decl
      # PROP-045: intent descriptor — queryable purpose metadata, not a behavior declaration
      when "intent"      then advance; parse_intent_decl
      when "pipeline"
        add_parse_error(
          rule: "OOF-P2",
          message: "pipeline/step is not valid inside a contract body",
          token: tok.value,
          line: tok.line,
          col: tok.col
        )
        skip_invalid_declaration_block
        nil
      when "step"
        add_parse_error(
          rule: "OOF-P2",
          message: "pipeline/step is not valid inside a contract body",
          token: tok.value,
          line: tok.line,
          col: tok.col
        )
        skip_invalid_body_decl
        nil
      when "scoped_by"
        add_parse_error(
          rule: "OOF-PG3",
          message: "scoped_by is only valid on read declarations",
          token: tok.value,
          line: tok.line,
          col: tok.col
        )
        skip_invalid_body_decl
        nil
      when "tenant_free"
        add_parse_error(
          rule: "OOF-PG5",
          message: "tenant_free is only valid on read declarations",
          token: tok.value,
          line: tok.line,
          col: tok.col
        )
        skip_invalid_body_decl
        nil
      else
        @errors << { "message" => "Unknown body declaration: #{tok.value}", "line" => tok.line }
        advance; nil
      end
    end

    def parse_input_decl
      name = name_token!(%i[ident keyword])
      expect_type!(:colon)
      type_ref = parse_type_ref
      { "kind" => "input", "name" => name, "type_annotation" => type_ref }
    end

    def parse_output_decl
      name = name_token!(%i[ident keyword])
      expect_type!(:colon)
      type_ref = parse_type_ref
      lifecycle = peek_kw?("lifecycle") ? (advance; parse_lifecycle) : nil
      node = { "kind" => "output", "name" => name, "type_annotation" => type_ref }
      node["lifecycle"] = lifecycle if lifecycle
      node["evidence"] = parse_evidence_list if peek_value?("evidence")
      node
    end

    # PROP-045: intent "..." — queryable purpose metadata for a contract or module.
    # Preserved through all pipeline stages into contract_ir as intent_text.
    # Not a behavior declaration; not a capability grant; not a policy.
    def parse_intent_decl
      tok = peek
      unless peek_type?(:string_lit)
        @errors << { "message" => "intent requires a string literal", "line" => tok.line }
        return nil
      end
      text = advance.value
      { "kind" => "intent", "text" => text }
    end

    def parse_uses_decl
      tok = peek
      if peek_kw?("assumptions")
        advance
        name = name_token!(%i[ident])
        return { "kind" => "uses_assumptions", "name" => name }
      elsif peek_type?(:ident)
        # LANG-TYPED-CONTRACT-REF-PROP-P3: `uses ContractName` or `uses Mod.Contract`
        target = advance.value
        while peek_type?(:dot)
          advance  # consume dot
          if peek_type?(:ident)
            target = "#{target}.#{advance.value}"
          else
            add_parse_error(
              rule: "OOF-P0",
              message: "expected contract name after '.' in uses declaration",
              token: peek&.value.to_s,
              line: peek&.line || 0,
              col: peek&.col || 0
            )
            break
          end
        end
        return { "kind" => "uses_contract", "name" => target, "target" => target }
      else
        add_parse_error(
          rule: "OOF-P0",
          message: "uses declaration requires 'uses assumptions NAME' or 'uses ContractName'",
          token: tok&.value.to_s,
          line: tok&.line || 0,
          col: tok&.col || 0
        )
        skip_until_body_boundary
        return nil
      end
    end

    def parse_evidence_list
      expect_value!("evidence")
      expect_type!(:lbracket)
      refs = []
      until peek_type?(:rbracket) || peek_type?(:eof)
        refs << name_token!(%i[ident keyword])
        advance if peek_type?(:comma)
      end
      expect_type!(:rbracket)
      refs
    end

    # LANG-CH13-WRITE-EVIDENCE-P60 (§13.6): `write <store> <- <value> evidence [refs]`.
    # An EFFECT STATEMENT (append to a temporal store), not an output decl. The
    # `evidence` clause is MANDATORY (missing ⇒ OOF-W1). The store is a bare target
    # ident (v0; declared-stream resolution is HELD); the value is an expression;
    # evidence refs resolve to declared local symbols in the TypeChecker (OOF-W2).
    # Placement (pure/observed refusal ⇒ OOF-W3) + append/lifecycle are downstream.
    def parse_write_decl
      store = name_token!(%i[ident keyword])
      unless peek_type?(:left_arrow)
        tok = peek
        add_parse_error(
          rule: "OOF-W1",
          message: "write to '#{store}' requires '<- <value> evidence [...]'",
          token: tok&.value.to_s, line: tok&.line || 0, col: tok&.col || 0
        )
        skip_invalid_body_decl
        return nil
      end
      advance # consume `<-`
      value = parse_expr
      refs = nil
      if peek_value?("evidence")
        refs = parse_evidence_list
      else
        tok = peek
        add_parse_error(
          rule: "OOF-W1",
          message: "write to '#{store}' requires a mandatory 'evidence [...]' clause",
          token: tok&.value.to_s, line: tok&.line || 0, col: tok&.col || 0
        )
      end
      { "kind" => "write", "store" => store, "value" => value, "evidence" => refs || [] }
    end

    # PROP-050 (ratified 2026-07-08) / LAB-EFFECT-CALL-V0-P3 (S1):
    #   invoke <name> = Callee(args...) using <cap> [, <cap>]*
    # Body-level effect-contract call DECLARATION (effect altitude, ordered with
    # effects) — never an expression. Malformed forms fail closed at parse time
    # with OOF-EC6: missing '=', missing 'contract', missing callee string
    # literal, missing or EMPTY `using` (D3: capability delegation must be
    # visible and non-empty at the call site). POSITIONAL violations in lambda /
    # branch position cannot parse by construction — `invoke` exists only in the
    # body-declaration grammar and the expression grammar has no invoke form;
    # loop-body placement (loops reuse parse_body_decl) is refused downstream
    # (OOF-EC6, TypeChecker loop-body scope check). Semantic rules OOF-EC1..EC5
    # run in the Classifier/TypeChecker. Declaration != execution: a parsed
    # invoke grants no runtime authority (PROP-050 EC-RUNTIME is gated).
    def parse_invoke_decl
      tok = peek
      unless tok && %i[ident keyword].include?(tok.type)
        add_parse_error(
          rule: "OOF-EC6",
          message: "invoke requires a binding name: invoke <name> = Callee(...) using <cap>",
          token: tok&.value.to_s, line: tok&.line || 0, col: tok&.col || 0
        )
        skip_until_body_boundary
        return nil
      end
      binding = advance.value
      unless peek_type?(:assign)
        return invoke_form_error(binding, "requires '=' after the binding name")
      end
      advance # consume `=`
      # LANG-EFFECT-CALL-NATURAL-SUGAR-P1: the canonical callee form is the natural
      # call spelling `invoke <name> = Callee(args...) using caps`. The legacy
      # `contract("Callee", ...)` spelling is a MIGRATION branch: parse far enough to
      # name the callee, then fail closed with ONE targeted OOF-EC6 showing the new
      # form (one canonical spelling, never two).
      if peek_value?("contract") && peek(1)&.type == :lparen
        advance # consume `contract`
        advance # consume `(`
        legacy_callee = peek_type?(:string_lit) ? advance.value : "Callee"
        tok = peek
        add_parse_error(
          rule: "OOF-EC6",
          message: "invoke '#{binding}': the contract(\"...\") spelling was retired — write the callee directly: invoke #{binding} = #{legacy_callee}(...) using <capability>",
          token: tok&.value.to_s, line: tok&.line || 0, col: tok&.col || 0
        )
        skip_until_body_boundary
        return nil
      end
      unless peek_type?(:ident)
        return invoke_form_error(binding, "requires the callee contract name (dynamic dispatch is closed)")
      end
      callee = advance.value
      while peek_type?(:dot)
        advance # consume `.`
        unless peek_type?(:ident)
          return invoke_form_error(binding, "has a trailing '.' in the qualified callee name")
        end
        callee = "#{callee}.#{advance.value}"
      end
      unless peek_type?(:lparen)
        return invoke_form_error(binding, "requires '(' after the callee name")
      end
      advance # consume `(`
      args = []
      unless peek_type?(:rparen)
        args << parse_expr
        while peek_type?(:comma)
          advance # consume `,`
          args << parse_expr
        end
      end
      unless peek_type?(:rparen)
        return invoke_form_error(binding, "requires ')' to close the callee argument list")
      end
      advance # consume `)`
      unless peek_kw?("using")
        return invoke_form_error(binding, "requires a mandatory 'using <cap>[, <cap>]*' clause (PROP-050 D3)")
      end
      advance # consume `using`
      unless peek_type?(:ident)
        return invoke_form_error(binding, "requires at least one capability name after 'using' (empty using is refused, PROP-050 D3)")
      end
      using = [advance.value]
      while peek_type?(:comma)
        advance # consume `,`
        unless peek_type?(:ident)
          return invoke_form_error(binding, "has a trailing ',' in the using clause without a capability name")
        end
        using << advance.value
      end
      { "kind" => "invoke", "binding" => binding, "callee" => callee,
        "args" => args, "using" => using }
    end

    # PROP-050: shared OOF-EC6 recovery for malformed invoke declarations —
    # record the parse error, fail closed (nil node), resynchronize without
    # consuming the contract's closing brace (skip_until_body_boundary stops at
    # rbrace/eof/next body keyword; skip_invalid_body_decl would advance blindly).
    def invoke_form_error(binding, detail)
      tok = peek
      add_parse_error(
        rule: "OOF-EC6",
        message: "invoke '#{binding}' #{detail}",
        token: tok&.value.to_s, line: tok&.line || 0, col: tok&.col || 0
      )
      skip_until_body_boundary
      nil
    end

    def parse_compute_decl
      name = name_token!(%i[ident keyword])
      type_ref = nil
      if peek_type?(:colon)
        advance
        type_ref = parse_type_ref
      end
      expect_type!(:assign)
      expr = parse_expr
      bound = parse_optional_stream_bound if expr.fetch("kind", nil) == "call" && expr.fetch("fn", nil) == "fold_stream"
      if bound
        node = { "kind" => "fold_stream", "name" => name, "expr" => expr }
        node["type_annotation"] = type_ref if type_ref
        node["bound"] = bound
        return node
      end
      node = { "kind" => "compute", "name" => name, "expr" => expr }
      node["type_annotation"] = type_ref if type_ref
      node
    end

    def parse_read_decl
      name = name_token!(%i[ident])
      expect_type!(:colon)
      type_ref = parse_type_ref
      expect_kw!("from")
      from = expect_type!(:string_lit).value
      lifecycle    = peek_kw?("lifecycle")      ? (advance; parse_lifecycle)              : nil
      scoped_by    = peek_kw?("scoped_by")     ? (advance; name_token!(%i[ident]))       : nil
      cardinality  = peek_kw?("cardinality")   ? (advance; parse_cardinality_bound)      : nil
      schema_ver   = peek_kw?("schema_version") ? (advance; expect_type!(:string_lit).value) : nil
      tenant_free  = peek_kw?("tenant_free")   ? (advance; true)                         : false
      if tenant_free && scoped_by
        @errors << { "message" => "OOF-PG3: scoped_by and tenant_free are mutually exclusive on read '#{name}'",
                     "line" => 0 }
      end
      node = { "kind" => "read", "name" => name, "type_annotation" => type_ref, "from" => from }
      node["lifecycle"]     = lifecycle   if lifecycle
      node["scoped_by"]     = scoped_by   if scoped_by
      node["cardinality"]   = cardinality if cardinality
      node["schema_version"] = schema_ver  if schema_ver
      node["tenant_free"]   = tenant_free
      node
    end

    def parse_cardinality_bound
      min_tok = expect_type!(:int_lit)
      # '..' is now lexed as a single :dot_dot token
      if peek_type?(:dot_dot)
        advance
      else
        tok = peek
        @errors << { "message" => "Expected '..' in cardinality, got #{tok&.value}", "line" => tok&.line }
      end
      max_tok = expect_type!(:int_lit)
      { "min" => min_tok.value, "max" => max_tok.value }
    end

    def parse_snapshot_decl
      name = name_token!(%i[ident])
      expect_type!(:assign)
      expr = parse_expr
      lifecycle = peek_kw?("lifecycle") ? (advance; parse_lifecycle) : nil
      node = { "kind" => "snapshot", "name" => name, "expr" => expr }
      node["lifecycle"] = lifecycle if lifecycle
      node
    end

    def parse_window_decl
      label = expect_type!(:string_lit).value
      expect_type!(:lbrace)
      opts = {}
      until peek_type?(:rbrace) || peek_type?(:eof)
        key = name_token!(%i[ident keyword])
        advance if peek_type?(:colon)  # consume optional : separator between key and value
        val = parse_window_value
        opts[key] = val
        advance if peek_type?(:comma)
      end
      expect_type!(:rbrace)
      { "kind" => "window", "label" => label, "options" => opts }
    end

    def parse_window_value
      if peek_type?(:int_lit)
        advance.value
      elsif peek_type?(:float_lit)
        advance.value
      elsif peek_type?(:symbol_lit)
        advance.value
      else
        name_token!(%i[ident keyword])
      end
    end

    def parse_escape_decl
      name = name_token!(%i[ident])
      { "kind" => "escape", "name" => name }
    end

    # PROP-035: capability <name>: <CapType>
    # LANG-NETWORK-CAPABILITY-GRAMMAR-P2: an IO.NetworkCapability declaration may
    # carry a structured `{ ... }` attribute block. DECLARED POLICY METADATA ONLY —
    # parsing it grants no authority, opens no socket, binds no executor
    # (enforcement stays host-side). Every static rule fails closed (OOF-NET*).
    def parse_capability_decl
      name = name_token!(%i[ident])
      expect_type!(:colon)
      type_ref = parse_type_ref
      decl = { "kind" => "capability", "name" => name, "type_annotation" => type_ref }
      if peek_type?(:lbrace)
        attrs = parse_network_capability_attrs(type_ref)
        decl["network_attributes"] = attrs if attrs
      end
      decl
    end

    # LANG-NETWORK-CAPABILITY-GRAMMAR-P2 static rules (bounded OOF-NET* family;
    # rules and messages are byte-identical with the Rust lab compiler):
    #   OOF-NET1  attribute block on a non-IO.NetworkCapability capability type
    #   OOF-NET2  unknown attribute field
    #   OOF-NET3  duplicate attribute field
    #   OOF-NET4  missing required attribute field
    #   OOF-NET5  wrong-typed / non-literal attribute value
    #   OOF-NET6  port outside 1..65535 or port_lo > port_hi
    #   OOF-NET7  dead grant: connect_allowed:false AND listen_allowed:false
    #   OOF-NET8  loopback_only:true weakened by "*" or a non-loopback host
    #   OOF-NET9  protocol vocabulary violation (v0: "tcp" only; "http" is an
    #             application operation over tcp — machine terminology tie-breaker)
    #   OOF-NET10 allowed_hosts entry is not a bare host literal
    # Returns the normalized attrs hash only when the whole block is valid; nil otherwise.
    NETWORK_CAPABILITY_FIELDS = {
      "protocol"        => "string",
      "allowed_hosts"   => "list of string literals",
      "port_lo"         => "integer",
      "port_hi"         => "integer",
      "loopback_only"   => "bool",
      "connect_allowed" => "bool",
      "listen_allowed"  => "bool",
      "tls_required"    => "bool"
    }.freeze

    def parse_network_capability_attrs(type_ref)
      lbrace = expect_type!(:lbrace)
      blk_line = lbrace.line
      blk_col  = lbrace.col
      type_name = type_ref.is_a?(Hash) ? (type_ref["name"] || "") : type_ref.to_s
      ok = true
      unless type_name == "IO.NetworkCapability"
        add_parse_error(
          rule: "OOF-NET1",
          message: "network capability attributes are only allowed on IO.NetworkCapability (got '#{type_name}')",
          token: "{",
          line: blk_line,
          col: blk_col
        )
        ok = false
      end

      seen = {}
      declared = []
      loop do
        tok = peek
        if tok.nil? || tok.type == :eof
          add_parse_error(
            rule: "OOF-NET5",
            message: "malformed network capability attribute block: unexpected end of input",
            token: "EOF",
            line: blk_line,
            col: blk_col
          )
          return nil
        elsif tok.type == :rbrace
          advance
          break
        elsif %i[ident keyword].include?(tok.type)
          field_tok = tok
          field = advance.value
          unless peek_type?(:colon)
            add_parse_error(
              rule: "OOF-NET5",
              message: "network capability attribute '#{field}' must be followed by ':'",
              token: field,
              line: field_tok.line,
              col: field_tok.col
            )
            skip_network_attr_value
            ok = false
            next
          end
          advance # consume ':'
          expected = NETWORK_CAPABILITY_FIELDS[field]
          if expected.nil?
            add_parse_error(
              rule: "OOF-NET2",
              message: "unknown network capability attribute '#{field}'",
              token: field,
              line: field_tok.line,
              col: field_tok.col
            )
            ok = false
          elsif declared.include?(field)
            add_parse_error(
              rule: "OOF-NET3",
              message: "duplicate network capability attribute '#{field}'",
              token: field,
              line: field_tok.line,
              col: field_tok.col
            )
            ok = false
          else
            declared << field
          end
          # Parse the literal value (even for unknown/dup fields — recovery).
          val, val_kind = parse_network_attr_literal
          if expected
            if val_kind == expected
              seen[field] = val unless seen.key?(field)
            else
              add_parse_error(
                rule: "OOF-NET5",
                message: "network capability attribute '#{field}' must be a literal #{expected}",
                token: field,
                line: field_tok.line,
                col: field_tok.col
              )
              ok = false
            end
          end
          advance if peek_type?(:comma)
        else
          add_parse_error(
            rule: "OOF-NET5",
            message: "malformed network capability attribute block: unexpected '#{tok.value}'",
            token: tok.value.to_s,
            line: tok.line,
            col: tok.col
          )
          advance
          ok = false
        end
      end

      # OOF-NET4 — all eight fields are required in v0 (no live precedent
      # establishes a safe default; fail closed).
      NETWORK_CAPABILITY_FIELDS.each_key do |field|
        next if declared.include?(field)

        add_parse_error(
          rule: "OOF-NET4",
          message: "missing required network capability attribute '#{field}'",
          token: field,
          line: blk_line,
          col: blk_col
        )
        ok = false
      end
      return nil unless ok

      protocol        = seen["protocol"]
      allowed_hosts   = seen["allowed_hosts"]
      port_lo         = seen["port_lo"]
      port_hi         = seen["port_hi"]
      loopback_only   = seen["loopback_only"]
      connect_allowed = seen["connect_allowed"]
      listen_allowed  = seen["listen_allowed"]
      tls_required    = seen["tls_required"]

      # OOF-NET9: protocol vocabulary. Decision (machine terminology tie-breaker,
      # igniter-machine/src/http.rs): HTTP is an APPLICATION OPERATION executed
      # over a TCP transport; v0 transport vocabulary is "tcp" only, and "http"
      # is refused explicitly rather than aliased silently.
      if protocol == "http"
        add_parse_error(
          rule: "OOF-NET9",
          message: "protocol \"http\" is an application operation over tcp; declare protocol: \"tcp\" (transport vocabulary per igniter-machine HttpCapabilityExecutor)",
          token: "http",
          line: blk_line,
          col: blk_col
        )
        ok = false
      elsif protocol != "tcp"
        add_parse_error(
          rule: "OOF-NET9",
          message: "unsupported network capability protocol '#{protocol}' (v0 supports \"tcp\" only; UDP is not implied)",
          token: protocol.to_s,
          line: blk_line,
          col: blk_col
        )
        ok = false
      end
      # OOF-NET6: port bounds.
      unless (1..65_535).cover?(port_lo) && (1..65_535).cover?(port_hi) && port_lo <= port_hi
        add_parse_error(
          rule: "OOF-NET6",
          message: "network capability port range invalid: port_lo and port_hi must be within 1..65535 and port_lo <= port_hi",
          token: "port_lo",
          line: blk_line,
          col: blk_col
        )
        ok = false
      end
      # OOF-NET7: dead grant — fail closed as an ERROR (live proof precedent has
      # no warning channel; a grant that can neither connect nor listen is
      # contradictory declared policy).
      if connect_allowed == false && listen_allowed == false
        add_parse_error(
          rule: "OOF-NET7",
          message: "dead network capability grant: connect_allowed and listen_allowed are both false",
          token: "connect_allowed",
          line: blk_line,
          col: blk_col
        )
        ok = false
      end
      # OOF-NET10 + OOF-NET8: host entry hygiene, then loopback containment.
      allowed_hosts.each do |host|
        if host.strip.empty? || host.include?("://") || host.include?("@") ||
           host.include?("{{") || host =~ /\s/
          add_parse_error(
            rule: "OOF-NET10",
            message: "network capability allowed_hosts entry '#{host}' must be a bare host literal (no scheme, userinfo, secrets, or whitespace)",
            token: host,
            line: blk_line,
            col: blk_col
          )
          ok = false
        elsif loopback_only && !literal_loopback_host?(host)
          add_parse_error(
            rule: "OOF-NET8",
            message: "loopback_only:true cannot be weakened by non-loopback allowed_hosts entry '#{host}'",
            token: host,
            line: blk_line,
            col: blk_col
          )
          ok = false
        end
      end
      return nil unless ok

      {
        "protocol"        => protocol,
        "allowed_hosts"   => allowed_hosts,
        "port_lo"         => port_lo,
        "port_hi"         => port_hi,
        "loopback_only"   => loopback_only,
        "connect_allowed" => connect_allowed,
        "listen_allowed"  => listen_allowed,
        "tls_required"    => tls_required
      }
    end

    def literal_loopback_host?(host)
      return true if host == "localhost" || host == "::1"

      octets = host.split(".", -1)
      octets.length == 4 && octets.first == "127" &&
        octets.all? { |octet| octet.match?(/\A\d+\z/) && (0..255).cover?(octet.to_i) }
    end

    # One attribute literal → [value, kind] where kind matches the
    # NETWORK_CAPABILITY_FIELDS vocabulary; [nil, nil] for anything non-literal.
    def parse_network_attr_literal
      tok = peek
      case tok&.type
      when :string_lit then [advance.value, "string"]
      when :int_lit    then [advance.value, "integer"]
      when :bool_lit   then [advance.value == "true", "bool"]
      when :lbracket
        advance
        items = []
        list_ok = true
        loop do
          t = peek
          if t.nil? || t.type == :eof
            list_ok = false
            break
          elsif t.type == :rbracket
            advance
            break
          elsif t.type == :string_lit
            items << advance.value
            advance if peek_type?(:comma)
          else
            list_ok = false
            advance
          end
        end
        list_ok ? [items, "list of string literals"] : [nil, nil]
      else
        advance unless tok.nil? || tok.type == :eof
        [nil, nil]
      end
    end

    # Recovery helper: skip tokens until the next comma or closing brace of the
    # network attribute block (does not consume the rbrace).
    def skip_network_attr_value
      loop do
        t = peek
        break if t.nil? || %i[eof rbrace comma].include?(t.type)

        advance
      end
      advance if peek_type?(:comma)
    end

    # PROP-035: effect <name> using <cap_ref>
    def parse_effect_binding_decl
      name = name_token!(%i[ident])
      expect_kw!("using")
      cap_ref = name_token!(%i[ident])
      { "kind" => "effect_binding", "name" => name, "capability_ref" => cap_ref }
    end

    # LANG-EFFECT-SURFACE-RECEIPT-FAILURE-P1: `receipt <TypeRef>` / `failure <TypeRef>`
    # Effect Surface metadata — declares the audit-proof / declared-failure output
    # types of an effectful contract. Metadata only: no behavior, no executor.
    def parse_receipt_decl
      { "kind" => "receipt", "type_annotation" => parse_type_ref }
    end

    def parse_failure_decl
      { "kind" => "failure", "type_annotation" => parse_type_ref }
    end

    # LANG-EFFECT-SURFACE-AUTHORITY-PARSER-P10: `authority <ident>` — DECLARED
    # authority intent only (ratified model F, ch12 §12.3): a bare role symbol
    # the HOST later resolves to passport scope(s). Parsing this clause is NOT
    # runtime enforcement. Dotted refs and string literals are refused
    # (OOF-M13) — roles are bare idents, host vocabulary stays out of source.
    def parse_authority_decl
      tok = peek
      if tok && %i[ident keyword].include?(tok.type)
        ref = advance.value
        # Dotted refs arrive two ways: `Billing.Operator` lexes as ONE ident
        # token (Module.Name path rule), `billing.operator` as ident + :dot.
        # The ident is already consumed here, so skip only the dotted TAIL if
        # one remains (skip_invalid_body_decl would eat one token too many).
        if ref.include?(".") || peek_type?(:dot)
          add_parse_error(
            rule: "OOF-M13",
            message: "authority reference must be a bare role ident (no dotted refs); got '#{ref}'",
            token: ref,
            line: tok.line,
            col: tok.col
          )
          skip_until_body_boundary if peek_type?(:dot)
          nil
        else
          { "kind" => "authority", "ref" => ref }
        end
      else
        add_parse_error(
          rule: "OOF-M13",
          message: "authority clause requires a bare role ident (e.g. 'authority billing_operator'); string literals are not accepted",
          token: tok&.value.to_s,
          line: tok&.line || 0,
          col: tok&.col || 0
        )
        skip_invalid_body_decl
        nil
      end
    end

    # LANG-EFFECT-SURFACE-AFFECTS-P5: `affects external|internal <qualified-name>`
    # — Effect Surface metadata naming the system the contract mutates. Metadata
    # only: no profile allowed_effects enforcement, no runtime behavior. The
    # qualified-name preserves source spelling (dotted identifier path).
    def parse_affects_decl
      tok = peek
      case tok&.value
      when "external", "internal"
        scope = tok.value
        advance
        { "kind" => "affects", "scope" => scope, "target" => parse_qualified_ref }
      else
        add_parse_error(
          rule: "OOF-M12",
          message: "affects clause requires a scope: 'external' or 'internal'",
          token: tok&.value.to_s,
          line: tok&.line || 0,
          col: tok&.col || 0
        )
        skip_invalid_body_decl
        nil
      end
    end

    # LANG-EFFECT-SURFACE-REVERSIBILITY-P25: `reversibility :<value>` — the last
    # Effect Surface metadata field. Colon symbol REQUIRED (severity/lifecycle
    # precedent; value stored WITHOUT the colon). Exactly the six ch12 scale
    # values; anything else fails closed with OOF-M16. Metadata only: no profile
    # max, no host/executor comparison, no required-field enforcement.
    REVERSIBILITY_VALUES = %w[reversible compensatable refundable append_only irreversible destructive].freeze

    def parse_reversibility_decl
      tok = peek
      unless tok && tok.type == :symbol_lit
        add_parse_error(
          rule: "OOF-M16",
          message: "reversibility requires a colon symbol value " \
                   "(:reversible|:compensatable|:refundable|:append_only|:irreversible|:destructive)",
          token: tok&.value.to_s,
          line: tok&.line || 0,
          col: tok&.col || 0
        )
        skip_invalid_body_decl unless tok.nil? || peek_type?(:rbrace)
        return nil
      end
      value = advance.value
      unless REVERSIBILITY_VALUES.include?(value)
        add_parse_error(
          rule: "OOF-M16",
          message: "unknown reversibility value ':#{value}'; allowed: " \
                   ":reversible :compensatable :refundable :append_only :irreversible :destructive",
          token: value,
          line: tok.line,
          col: tok.col
        )
        # symbol token already consumed — nothing to skip (P22 lesson: skipping
        # after a fully-consumed clause eats the contract's closing brace).
        return nil
      end
      { "kind" => "reversibility", "value" => value }
    end

    # LANG-EFFECT-SURFACE-COMPENSATION-P22: `compensation <ContractName>` |
    # `no_compensation` — Effect Surface metadata naming the compensating
    # contract (or explicitly waiving one). Declaration only: grants NO
    # authority, binds NO host executor, executes NOTHING. v0 ref = bare
    # same-module contract ident; dotted refs fail closed (OOF-M14).
    def parse_compensation_decl
      tok = peek
      unless tok && %i[ident keyword].include?(tok.type)
        add_parse_error(
          rule: "OOF-M14",
          message: "compensation clause requires a bare contract name or use 'no_compensation'",
          token: tok&.value.to_s,
          line: tok&.line || 0,
          col: tok&.col || 0
        )
        skip_invalid_body_decl
        return nil
      end
      ref = name_token!(%i[ident keyword])
      # The lexer folds dotted paths into one ident token (`IO.NetworkCapability`
      # style), so a dotted ref arrives INSIDE the name — check the name itself.
      if ref.include?(".") || peek_type?(:dot)
        add_parse_error(
          rule: "OOF-M14",
          message: "compensation ref must be a bare same-module contract name; dotted refs fail closed in v0",
          token: ref,
          line: tok.line,
          col: tok.col
        )
        # The dotted ref was one lexed token, already consumed — nothing to skip.
        return nil
      end
      { "kind" => "compensation", "contract_ref" => ref }
    end

    # LANG-EFFECT-SURFACE-IDEMPOTENCY-P2: `idempotency key <expr>` | `idempotency
    # natural` | `idempotency none` — Effect Surface metadata declaring the
    # idempotency contract of an effectful operation. Metadata only: no retry
    # runner, no enforcement. The key expression flows through the pipeline as a
    # normal expr (`"expr"` field) so classifier/typechecker handle it uniformly.
    def parse_idempotency_decl
      tok = peek
      case tok&.value
      when "key"
        advance
        { "kind" => "idempotency", "mode" => "key", "expr" => parse_expr }
      when "natural", "none"
        mode = tok.value
        advance
        { "kind" => "idempotency", "mode" => mode }
      else
        add_parse_error(
          rule: "OOF-M11",
          message: "idempotency clause requires a mode: 'key <expr>', 'natural', or 'none'",
          token: tok&.value.to_s,
          line: tok&.line || 0,
          col: tok&.col || 0
        )
        skip_invalid_body_decl
        nil
      end
    end

    # PINV-3: parse invariant declaration
    # invariant <name>
    #   predicate: <compute_ref>
    #   severity: :<error|warn|soft|metric>   (default: error)
    #   label: "<string>"                     (optional)
    #   message: "<string>"                   (optional)
    #   overridable_with: :<symbol>            (optional; only on :warn)
    def parse_invariant_decl
      name_tok = peek
      name = name_token!(%i[ident])
      predicate_ref = nil
      severity = "error"
      label = nil
      message = nil
      overridable_with = nil

      # Parse attribute lines until we hit something that doesn't look like an attribute
      while peek_kw?("predicate") || peek_kw?("severity") || peek_kw?("label") ||
            peek_kw?("message") || peek_kw?("overridable_with")
        attr_tok = peek
        attr = advance.value
        expect_type!(:colon)
        case attr
        when "predicate"
          predicate_ref = name_token!(%i[ident])
        when "severity"
          if peek_type?(:symbol_lit)
            severity = advance.value
            unless %w[error warn soft metric].include?(severity)
              add_parse_error(
                rule: "OOF-IV2",
                message: "Unknown severity '#{severity}'; expected :error :warn :soft :metric",
                token: severity,
                line: attr_tok.line,
                col: attr_tok.col
              )
              severity = "error" # recover
            end
          else
            add_parse_error(
              rule: "OOF-IV2",
              message: "severity: requires a symbol literal (:error, :warn, :soft, :metric)",
              token: peek&.value.to_s,
              line: attr_tok.line,
              col: attr_tok.col
            )
          end
        when "label"
          label = peek_type?(:string_lit) ? advance.value : name_token!(%i[ident])
        when "message"
          message = peek_type?(:string_lit) ? advance.value : name_token!(%i[ident])
        when "overridable_with"
          overridable_with = peek_type?(:symbol_lit) ? advance.value : name_token!(%i[ident])
        end
      end

      # PINV-3: OOF-IV1 — missing predicate: field
      if predicate_ref.nil?
        add_parse_error(
          rule: "OOF-IV1",
          message: "invariant '#{name}' missing required predicate: field",
          token: name,
          line: name_tok.line,
          col: name_tok.col
        )
      end

      # PINV-3: OOF-I4 — overridable_with: on severity: :error invariant (static case)
      if overridable_with && severity == "error"
        add_parse_error(
          rule: "OOF-I4",
          message: ":error invariants cannot be overridden — use :warn if override is intended",
          token: name,
          line: name_tok.line,
          col: name_tok.col
        )
      end

      {
        "kind"             => "invariant",
        "name"             => name,
        "predicate_ref"    => predicate_ref,
        "severity"         => severity,
        "label"            => label,
        "message"          => message,
        "overridable_with" => overridable_with,
        "source_span"      => {
          "line" => name_tok.line,
          "col" => name_tok.col
        }
      }
    end

    def parse_stream_decl
      # stream <name>: <Type>
      name = name_token!(%i[ident])
      expect_type!(:colon)
      type_ref = parse_type_ref
      {
        "kind"             => "stream",
        "name"             => name,
        "type_annotation"  => type_ref,
        "fragment_class"   => "escape",
        "escape_capability" => "stream_input"
      }
    end

    def parse_fold_stream_decl
      # fold_stream <name> = fold_stream(<stream_ref>, <init>, <fn>) @<bound_annotation>
      name_tok = peek
      name = name_token!(%i[ident])
      expect_type!(:assign)
      # consume optional explicit 'fold_stream' call name (may already be consumed as keyword)
      # Expression parser handles the call: fold_stream(stream_ref, init, fn)
      expr = parse_expr
      # Parse optional bound annotation: @window_bounded or @count_bounded(n)
      bound = parse_optional_stream_bound
      unless bound
        # No bound annotation — OOF-S1: unbounded fold
        add_parse_error(
          rule: "OOF-S1",
          message: "fold_stream '#{name}' is unbounded — must declare @window_bounded or @count_bounded(n)",
          token: name,
          line: name_tok.line,
          col: name_tok.col
        )
      end
      node = { "kind" => "fold_stream", "name" => name, "expr" => expr }
      node["bound"] = bound if bound
      node
    end

    def parse_optional_stream_bound
      return nil unless peek_type?(:at)

      at_tok = advance
      bound_name = name_token!(%i[ident keyword])
      case bound_name
      when "window_bounded"
        { "kind" => "window_bounded" }
      when "count_bounded"
        expect_type!(:lparen)
        n_tok = peek
        if peek_type?(:int_lit)
          n = advance.value
          bound = { "kind" => "count_bounded", "n" => n }
        else
          add_parse_error(
            rule: "OOF-S5",
            message: "@count_bounded requires a statically-known Integer literal",
            token: n_tok&.value.to_s,
            line: n_tok&.line || 0,
            col: n_tok&.col || 0
          )
          bound = { "kind" => "count_bounded", "n" => nil }
        end
        expect_type!(:rparen)
        bound
      else
        add_parse_error(
          rule: "OOF-S1",
          message: "Unknown bound annotation '@#{bound_name}'; expected @window_bounded or @count_bounded(n)",
          token: bound_name,
          line: at_tok.line,
          col: at_tok.col
        )
        nil
      end
    end

    # ---- Type declarations -------------------------------------------------

    def parse_type_decl
      name = name_token!(%i[ident])
      expect_type!(:lbrace)
      fields = []
      until peek_type?(:rbrace) || peek_type?(:eof)
        fname = name_token!(%i[ident keyword])
        expect_type!(:colon)
        ftype = parse_type_ref
        optional = peek_type?(:question) ? (advance; true) : false
        fields << { "name" => fname, "type_annotation" => ftype, "optional" => optional }
        advance if peek_type?(:comma)
      end
      expect_type!(:rbrace)
      { "kind" => "type", "name" => name, "fields" => fields }
    end

    # ---- Function declarations ---------------------------------------------

    def parse_function_decl
      name = name_token!(%i[ident])
      params = parse_params
      expect_type!(:arrow)
      return_type = parse_type_ref
      # OOF-L4: optional `decreases fuel` annotation between return type and body
      decreases = nil
      if peek_kw?("decreases")
        advance
        decreases = name_token!(%i[ident keyword])
      end
      body = parse_block_body
      result = { "kind" => "function", "name" => name, "params" => params,
                 "return_type" => return_type, "body" => body }
      result["decreases"] = decreases if decreases
      result
    end

    def parse_params
      expect_type!(:lparen)
      params = []
      until peek_type?(:rparen) || peek_type?(:eof)
        pname = name_token!(%i[ident keyword])
        expect_type!(:colon)
        ptype = parse_type_ref
        params << { "name" => pname, "type_annotation" => ptype }
        advance if peek_type?(:comma)
      end
      expect_type!(:rparen)
      params
    end

    def parse_block_body
      expect_type!(:lbrace)
      stmts = []
      expr  = nil
      until peek_type?(:rbrace) || peek_type?(:eof)
        if peek_kw?("let")
          stmts << parse_let_stmt
        else
          expr = parse_expr
          break if peek_type?(:rbrace)
          stmts << { "kind" => "expr_stmt", "expr" => expr }
          expr = nil
        end
      end
      expect_type!(:rbrace)
      { "stmts" => stmts, "return_expr" => expr }
    end

    def parse_let_stmt
      expect_kw!("let")
      name = name_token!(%i[ident keyword])
      expect_type!(:assign)
      expr = parse_expr
      { "kind" => "let", "name" => name, "expr" => expr }
    end

    # ---- TypeRef -----------------------------------------------------------

    def parse_simple_type_params
      expect_type!(:lbracket)
      params = []
      until peek_type?(:rbracket) || peek_type?(:eof)
        params << name_token!(%i[ident])
        advance if peek_type?(:comma)
      end
      expect_type!(:rbracket)
      params
    end

    def parse_contract_type_params
      expect_type!(:lbracket)
      params = []
      until peek_type?(:rbracket) || peek_type?(:eof)
        name = name_token!(%i[ident])
        bounds = peek_type?(:colon) ? (advance; parse_type_param_bounds(name)) : []
        params << { "name" => name, "bounds" => bounds }
        advance if peek_type?(:comma)
      end
      expect_type!(:rbracket)
      params
    end

    def parse_type_param_bounds(param_name)
      bounds = []
      loop do
        trait_ref = parse_type_ref_node(default_type_args: [param_name])
        bounds << { "trait_ref" => trait_ref }
        break unless peek_value?("&")

        advance
      end
      bounds
    end

    # ── PROP-039 gate 3: loop / recursion parse methods ─────────────────────

    # for <LoopName> <item> in <source> { body }
    def parse_for_loop
      loop_name = name_token!(%i[ident])
      item_name = name_token!(%i[ident])
      expect_value!("in")
      source    = name_token!(%i[ident])
      expect_type!(:lbrace)
      body = []
      until peek_type?(:rbrace) || peek_type?(:eof)
        body << parse_body_decl
      end
      expect_type!(:rbrace)
      { "kind" => "for_loop", "name" => loop_name, "item" => item_name,
        "source" => source, "body" => body.compact }
    end

    # loop <LoopName> <item> in <source> max_steps[:]? <N> { body }
    def parse_budgeted_loop
      loop_name = name_token!(%i[ident])
      item_name = name_token!(%i[ident])
      expect_value!("in")
      source    = name_token!(%i[ident])
      max_steps = nil
      if peek_value?("max_steps")
        advance                          # consume "max_steps"
        advance if peek_type?(:colon)    # optional ":"
        tok = expect_type!(:int_lit)
        max_steps = tok.value
      end
      expect_type!(:lbrace)
      body = []
      until peek_type?(:rbrace) || peek_type?(:eof)
        body << parse_body_decl
      end
      expect_type!(:rbrace)
      node = { "kind" => "budgeted_loop", "name" => loop_name, "item" => item_name,
               "source" => source, "body" => body.compact }
      node["max_steps"] = max_steps unless max_steps.nil?
      node
    end

    # PROP-039 gate 8: lead <name> : <Type> = <initial-literal>
    # Explicit loop-carried binding; valid inside loop body only.
    def parse_lead_decl
      name = name_token!(%i[ident])
      expect_type!(:colon)
      type_ref = parse_type_ref
      expect_type!(:assign)
      initial  = parse_expr
      { "kind" => "lead", "name" => name, "type_annotation" => type_ref, "initial" => initial }
    end

    # decreases <variant>
    #   PROP-039 / PROP-041 / PROP-042 dispatch:
    #   decreases <ident>            → T1 simple-identifier   (e.g. "n")
    #   decreases <ident>.<ident>    → T2 dotted-path         (e.g. "items.tail")
    #   decreases <ident>(<ident>)   → T3 function-call form  (e.g. "count(items)")
    def parse_decreases_decl
      fn_or_var = name_token!(%i[ident])

      # PROP-042 T3: function-call form — decreases count(items)
      if peek_type?(:lparen)
        advance                    # consume (
        arg = name_token!(%i[ident])
        expect_type!(:rparen)      # consume )
        return { "kind" => "decreases", "variant" => "#{fn_or_var}(#{arg})" }
      end

      # T1 / T2: simple-identifier or dotted-path
      parts = [fn_or_var]
      while peek_type?(:dot)
        advance
        parts << name_token!(%i[ident])
      end
      { "kind" => "decreases", "variant" => parts.join(".") }
    end

    # max_steps[:]? <N>  — inside recursive/fuel_bounded contract body
    def parse_max_steps_decl
      advance if peek_type?(:colon)    # optional ":"
      tok = expect_type!(:int_lit)
      { "kind" => "max_steps", "value" => tok.value }
    end

    # PROP-050/P46: ConvergentLoop obligation clauses. These are DECLARATIONS the
    # compiler checks for presence (OOF-R12/R13/R14 — R8..R11 are TAKEN by
    # PROP-041/042 size-relations/measures, despite the stale ch13 §13.7 "R1..R7"
    # list); the metric/threshold are a RUNTIME concern — the compiler never
    # proves convergence. Termination is guaranteed by `max_steps` (fuel),
    # exactly like `fuel_bounded`.

    # `variant <metric-expr>` — the convergence metric (e.g. `loss(params)`).
    # Parsed like `decreases` (fn(arg) / ident / dotted); presence is what matters.
    def parse_convergence_variant_decl
      fn_or_var = name_token!(%i[ident])
      if peek_type?(:lparen)
        advance
        arg = name_token!(%i[ident])
        expect_type!(:rparen)
        return { "kind" => "convergence_variant", "metric" => "#{fn_or_var}(#{arg})" }
      end
      parts = [fn_or_var]
      while peek_type?(:dot)
        advance
        parts << name_token!(%i[ident])
      end
      { "kind" => "convergence_variant", "metric" => parts.join(".") }
    end

    # `convergence epsilon: <numeric-literal>` — the convergence threshold.
    def parse_convergence_decl
      expect_value!("epsilon")
      expect_type!(:colon)
      tok = peek
      if peek_type?(:float_lit) || peek_type?(:int_lit)
        advance
        { "kind" => "convergence", "epsilon" => tok.value }
      else
        add_parse_error(
          rule: "OOF-R13",
          message: "convergence epsilon must be a numeric literal",
          token: tok&.value.to_s,
          line: tok&.line || 0,
          col: tok&.col || 0
        )
        nil
      end
    end

    # `on_exhaustion :<action>` — behaviour when fuel exhausts before convergence.
    # Malformed / unknown action fails closed (dropped) so the classifier reports
    # the obligation as missing (OOF-R14).
    def parse_on_exhaustion_decl
      tok = peek
      unless peek_type?(:symbol_lit) && ON_EXHAUSTION_ACTIONS.include?(tok.value)
        add_parse_error(
          rule: "OOF-R14",
          message: "on_exhaustion requires a :symbol action " \
                   "(#{ON_EXHAUSTION_ACTIONS.map { |a| ":#{a}" }.join(' | ')})",
          token: tok&.value.to_s,
          line: tok&.line || 0,
          col: tok&.col || 0
        )
        advance if peek_type?(:symbol_lit)   # consume the bad symbol if present
        return nil
      end
      advance
      { "kind" => "on_exhaustion", "action" => tok.value }
    end

    # PROP-037 annex/P50: ServiceLoop obligation clauses. These are compile-time
    # DECLARATION checks (presence only, OOF-SL1/2/3) — they grant NO runtime
    # liveness; a step blocking the heartbeat or exceeding the latency budget is
    # a RUNTIME condition (OOF-SL10+, HELD, PROP-037 + the lab machine). A
    # `<duration>` is `<int>.<unit>` (e.g. `10.seconds`); v0 captures it loosely.

    def parse_duration
      n = expect_type!(:int_lit)
      expect_type!(:dot)
      unit = name_token!(%i[ident])
      "#{n.value}.#{unit}"
    end

    # `heartbeat every <duration>`
    def parse_heartbeat_decl
      expect_value!("every")
      { "kind" => "heartbeat", "interval" => parse_duration }
    end

    # `checkpoint every <duration>` (optional in v0)
    def parse_checkpoint_decl
      expect_value!("every")
      { "kind" => "checkpoint", "interval" => parse_duration }
    end

    # `cancellation <required|optional|none>`
    def parse_cancellation_decl
      tok = peek
      unless (tok&.type == :ident || tok&.type == :keyword) && CANCELLATION_MODES.include?(tok.value)
        add_parse_error(
          rule: "OOF-SL2",
          message: "cancellation requires a mode (#{CANCELLATION_MODES.join(' | ')})",
          token: tok&.value.to_s,
          line: tok&.line || 0,
          col: tok&.col || 0
        )
        advance if tok && (tok.type == :ident || tok.type == :keyword)
        return nil
      end
      advance
      { "kind" => "cancellation", "mode" => tok.value }
    end

    # `max_step_latency <duration>`
    def parse_max_step_latency_decl
      { "kind" => "max_step_latency", "budget" => parse_duration }
    end

    def parse_implements_clause
      expect_kw!("implements")
      parse_type_ref_node
    end

    def parse_type_ref_node(default_type_args: [])
      name = name_token!(%i[ident keyword])
      type_args = []
      if peek_type?(:lbracket)
        advance
        until peek_type?(:rbracket) || peek_type?(:eof)
          type_args << parse_type_ref
          advance if peek_type?(:comma)
        end
        expect_type!(:rbracket)
      elsif default_type_args.any?
        type_args = default_type_args
      end
      { "name" => name, "type_args" => type_args }
    end

    def parse_qualified_ref
      parts = [name_token!(%i[ident keyword])]
      while peek_type?(:dot)
        advance
        parts << name_token!(%i[ident keyword])
      end
      parts.join(".")
    end

    def parse_type_ref
      name_tok = peek
      name = name_token!(%i[ident keyword])
      if peek_type?(:lbracket)
        advance
        # Decimal[N]: structured node with integer scale param
        if name == "Decimal" && peek_type?(:int_lit)
          scale = advance.value  # Integer
          expect_type!(:rbracket)
          return { "kind" => "type_ref", "name" => "Decimal", "params" => [scale] }
        end
        params = []
        until peek_type?(:rbracket) || peek_type?(:eof)
          params << parse_type_ref_param(name, params.length)
          advance if peek_type?(:comma)
        end
        expect_type!(:rbracket)
        { "kind" => "type_ref", "name" => name, "params" => params }
      else
        if name == "Decimal"
          add_parse_error(
            rule: "OOF-DM3",
            message: "Decimal type requires scale parameter: Decimal[N]",
            token: name,
            line: name_tok.line,
            col: name_tok.col
          )
          return { "kind" => "type_ref", "name" => "Unknown", "original" => "Decimal", "params" => [] }
        end
        name
      end
    end

    def parse_type_ref_param(parent_name, index)
      if parent_name == "OLAPPoint" && index == 1 && peek_type?(:lbrace)
        { "kind" => "dims_record", "dims" => parse_olap_type_map }
      else
        normalize_type_param(parse_type_ref)
      end
    end

    # Normalize a bare type name string into a structured TypeRef node.
    # Used only when assembling params inside a generic type like History[T].
    # Existing callers that receive bare strings are unaffected.
    def normalize_type_param(ref)
      ref.is_a?(String) ? { "kind" => "type_ref", "name" => ref, "params" => [] } : ref
    end

    def add_parse_error(rule:, message:, token:, line:, col:, severity: "error")
      @errors << {
        "rule" => rule,
        "severity" => severity,
        "message" => message,
        "token" => token,
        "line" => line,
        "col" => col
      }
    end

    def skip_optional_block_or_step_tail
      if peek_type?(:lbrace)
        skip_balanced_block
        return
      end

      skip_until_body_boundary
    end

    def skip_invalid_body_decl
      advance
      if peek_type?(:lbrace)
        skip_balanced_block
        return
      end

      skip_until_body_boundary
    end

    def skip_invalid_declaration_block
      advance
      until peek_type?(:eof) || peek_type?(:rbrace) || peek_type?(:lbrace)
        advance
      end
      skip_balanced_block if peek_type?(:lbrace)
    end

    def skip_balanced_block
      return unless peek_type?(:lbrace)

      depth = 0
      loop do
        tok = advance
        depth += 1 if tok.type == :lbrace
        depth -= 1 if tok.type == :rbrace
        break if depth <= 0 || peek_type?(:eof)
      end
    end

    def skip_until_body_boundary
      until peek_type?(:eof) || peek_type?(:rbrace) || body_boundary_token?(peek)
        advance
      end
    end

    def skip_until_olap_clause_boundary
      until peek_type?(:eof) || peek_type?(:rbrace) || olap_clause_boundary?(peek, peek(1))
        advance
      end
    end

    def body_boundary_token?(tok)
      tok&.type == :keyword &&
        %w[input output compute read snapshot window escape stream fold_stream invariant uses pipeline step scoped_by tenant_free].include?(tok.value)
    end

    def olap_clause_boundary?(tok, next_tok)
      tok && %i[ident keyword].include?(tok.type) &&
        %w[dimensions measure granularity source indexed].include?(tok.value) &&
        next_tok&.type == :colon
    end

    def parse_lifecycle
      tok = advance  # should be :symbol_lit
      tok.value
    end

    def parse_lifecycle_or_symbol
      if peek_type?(:symbol_lit)
        advance.value
      else
        name_token!(%i[ident keyword])
      end
    end

    # ---- Expressions -------------------------------------------------------

    def parse_expr
      parse_binary_or(0)
    end

    def parse_binary_or(min_prec)
      left = parse_unary

      loop do
        op = peek&.value
        prec = binary_prec(op)
        break if prec.nil? || prec < min_prec

        op_tok = advance
        right  = parse_binary_or(prec + 1)
        left   = { "kind" => "binary_op", "op" => op_tok.value, "left" => left, "right" => right }
      end

      left
    end

    BINARY_OPS = {
      "||" => 1, "&&" => 2,
      "==" => 3, "!=" => 3, "<" => 3, ">" => 3, "<=" => 3, ">=" => 3,
      "++" => 4,
      "+"  => 5, "-" => 5,
      "*"  => 6, "/" => 6
    }.freeze

    def binary_prec(op)
      BINARY_OPS[op]
    end

    def parse_unary
      if peek_type?(:bang)
        op = advance.value
        expr = parse_postfix
        return { "kind" => "unary_op", "op" => op, "operand" => expr }
      end
      if peek_type?(:op) && peek&.value == "-"
        op = advance.value
        expr = parse_postfix
        return { "kind" => "unary_op", "op" => op, "operand" => expr }
      end
      parse_postfix
    end

    def parse_postfix
      expr = parse_primary

      loop do
        if peek_type?(:dot)
          advance
          field = name_token!(%i[ident keyword])
          expr = { "kind" => "field_access", "object" => expr, "field" => field }
        elsif peek_type?(:lbracket)
          advance
          index = index_slice_ahead? ? parse_index_slice_record : parse_expr
          expect_type!(:rbracket)
          expr = { "kind" => "index_access", "object" => expr, "index" => index }
        elsif peek_type?(:lparen) && (fn_name = callable_path_name(expr))
          # function call: bare `name(args)` OR qualified dotted `a.b.c(args)`.
          # LANG-RUBY-QUALIFIED-CALL-EXPR-PARSER-P2: before this production, a dotted path
          # (`stdlib.IO.read_text`) parsed as field accesses and the following `(` fell through —
          # at RHS root the body reader sprayed "Unknown body declaration: (", and nested inside
          # another call's args the `(` was taken as a GROUPING paren whose first comma hit the
          # hard expect_type!(:rparen) raise. A pure dotted NAME path followed by `(` is now a
          # call with the joined dotted `fn` (typecheck decides what the name means — parser
          # makes no stdlib/IO claim); computed objects (call/index results) keep the old
          # non-call postfix behavior.
          advance
          args = []
          until peek_type?(:rparen) || peek_type?(:eof)
            args << parse_call_arg
            advance if peek_type?(:comma)
          end
          expect_type!(:rparen)
          expr = { "kind" => "call", "fn" => fn_name, "args" => args }
        else
          break
        end
      end

      expr
    end

    # LANG-RUBY-QUALIFIED-CALL-EXPR-PARSER-P2: a callable target is a bare ref or a pure dotted
    # name path — a field_access chain whose base is a ref and whose links are simple names.
    # Returns the joined dotted name ("stdlib.IO.read_text") or nil for anything computed.
    def callable_path_name(expr)
      case expr["kind"]
      when "ref"
        expr["name"]
      when "field_access"
        base = callable_path_name(expr["object"])
        base ? "#{base}.#{expr["field"]}" : nil
      end
    end

    def index_slice_ahead?
      %i[ident keyword].include?(peek&.type) && peek(1)&.type == :colon
    end

    def parse_index_slice_record
      fields = {}
      until peek_type?(:rbracket) || peek_type?(:eof)
        key = name_token!(%i[ident keyword])
        expect_type!(:colon)
        fields[key] = parse_expr
        advance if peek_type?(:comma)
      end
      { "kind" => "slice_record", "fields" => fields }
    end

    def parse_call_arg
      # Check for lambda: "name ->" or "(params) ->"
      if peek_type?(:lparen) && lambda_ahead?
        parse_lambda
      elsif (peek_type?(:ident) || peek_type?(:keyword)) && peek(1)&.type == :arrow
        parse_lambda
      else
        parse_expr
      end
    end

    def lambda_ahead?
      saved = @pos
      depth = 0
      while @pos < @tokens.length
        t = @tokens[@pos]
        case t.type
        when :lparen then depth += 1
        when :rparen then
          depth -= 1
          if depth == 0
            @pos += 1
            result = @tokens[@pos]&.type == :arrow
            @pos = saved
            return result
          end
        when :eof then break
        end
        @pos += 1
      end
      @pos = saved
      false
    end

    def parse_lambda
      params = []
      if peek_type?(:lparen)
        advance
        until peek_type?(:rparen) || peek_type?(:eof)
          pname = name_token!(%i[ident keyword])
          params << pname
          advance if peek_type?(:comma)
        end
        expect_type!(:rparen)
      elsif peek_type?(:ident) || peek_type?(:keyword)
        params << advance.value
      end
      expect_type!(:arrow)
      # LAB-PARSER-RECORD-IN-HOF-P2: after `->`, a `{` that opens `ident :` (or `keyword :`) is a
      # record-literal body, not a statement block. A bounded 3-token lookahead routes it through
      # parse_record_or_block; every other `{` body (a `{ let … }` block, a multi-statement block,
      # empty `{}`, or a nested block) keeps parse_lambda_block. Malformed record syntax fails closed
      # inside parse_record_or_block (name_token!/expect_type!(:colon)/parse_expr record a diagnostic),
      # never silently recovering into a block AST.
      body = if lambda_body_record_literal?
               parse_record_or_block
             elsif peek_type?(:lbrace)
               parse_lambda_block
             else
               parse_expr
             end
      { "kind" => "lambda", "params" => params, "body" => body }
    end

    # LAB-PARSER-RECORD-IN-HOF-P2: bounded lookahead — true iff the upcoming tokens are
    # `{ <name> :`, a record-literal opening in lambda-body position. `<name>` is an :ident or
    # :keyword (record fields may be keyword-named); the `:` at offset +2 distinguishes a record
    # from a `{ let x = … }` block (offset +2 is the binding name there, not a colon) and from
    # `{ expr }` / empty `{}` block bodies.
    def lambda_body_record_literal?
      peek_type?(:lbrace) &&
        %i[ident keyword].include?(peek(1)&.type) &&
        peek(2)&.type == :colon
    end

    def parse_lambda_block
      expect_type!(:lbrace)
      stmts = []
      expr  = nil
      until peek_type?(:rbrace) || peek_type?(:eof)
        if peek_kw?("let")
          stmts << parse_let_stmt
        else
          expr = parse_expr
          break if peek_type?(:rbrace)
          stmts << { "kind" => "expr_stmt", "expr" => expr }
          expr = nil
        end
      end
      expect_type!(:rbrace)
      { "kind" => "block", "stmts" => stmts, "return_expr" => expr }
    end

    def parse_primary
      tok = peek

      case tok.type
      when :keyword
        case tok.value
        when "if"    then advance; parse_if_expr
        when "match" then advance; parse_match_expr              # PROP-044-P3
        when "true"  then advance; { "kind" => "literal", "value" => true,  "type_tag" => "Bool" }
        when "false" then advance; { "kind" => "literal", "value" => false, "type_tag" => "Bool" }
        when "nil"   then advance; { "kind" => "literal", "value" => nil,   "type_tag" => "Nil" }
        else
          advance; { "kind" => "ref", "name" => tok.value }
        end
      when :ident
        advance
        # PROP-044-P3: PascalCase ident immediately followed by { → variant construct
        if tok.value[0] =~ /[A-Z]/ && peek_type?(:lbrace)
          parse_variant_construct(tok.value)
        elsif form_invocation_start?
          parse_form_invocation(tok.value)
        else
          { "kind" => "ref", "name" => tok.value }
        end
      when :int_lit
        advance; { "kind" => "literal", "value" => tok.value, "type_tag" => "Integer" }
      when :float_lit
        advance; { "kind" => "literal", "value" => tok.value, "type_tag" => "Float" }
      when :string_lit
        advance; { "kind" => "literal", "value" => tok.value, "type_tag" => "String" }
      # LANG-RUBY-STRING-ESCAPES-PARITY-P2: a malformed lexeme (invalid escape /
      # unterminated string). `tok.value` carries the lexer's reason — surface it
      # verbatim as OOF-LEX1, mirroring Rust's `TokenType::Illegal` handling in
      # `parse_primary` (igniter-compiler src/parser.rs) exactly.
      when :illegal
        reason = tok.value
        advance
        add_parse_error(rule: "OOF-LEX1", message: reason, token: reason, line: tok.line, col: tok.col)
        { "kind" => "error", "token" => reason }
      when :symbol_lit
        advance; { "kind" => "symbol", "value" => tok.value }
      when :bool_lit
        advance; { "kind" => "literal", "value" => tok.value == "true", "type_tag" => "Bool" }
      when :lbracket
        parse_array_literal
      when :lbrace
        parse_record_or_block
      when :lparen
        advance
        expr = parse_expr
        expect_type!(:rparen)
        expr
      else
        @errors << { "message" => "Unexpected token in expression: #{tok.type}(#{tok.value})", "line" => tok.line }
        # LANG-RUBY-VARIANT-MATCH-PARSER-P1: never consume the :eof sentinel —
        # doing so left peek == nil and crashed every enclosing loop with
        # NoMethodError on truncated input (fail-open, not fail-closed).
        advance unless tok.type == :eof
        { "kind" => "error", "token" => tok.value }
      end
    end

    def form_invocation_start?
      # LANG-RUBY-IF-COND-BARE-IDENT-FORM-GUARD-P1: inside an `if` condition a
      # lowercase ident before `{` must stay a plain ref — the `{` opens the
      # then-block, not a Gap-I form invocation (`if flag { ... } else { ... }`).
      # LANG-RUBY-VARIANT-MATCH-PARSER-P1: same guard for `match` subjects —
      # `match v { A { x } => x }` must keep `v` a plain ref so `{` opens the
      # match body (IGDB-P23 crash class).
      # Rust parity: lab parser only constructs on PascalCase ident before `{`,
      # so bare value idents in these header positions never claim the block.
      return false if (@form_guard_depth || 0).positive?

      peek_type?(:lbrace) ||
        (%i[ident keyword].include?(peek&.type) && peek(1)&.type == :assign)
    end

    def parse_form_invocation(trigger)
      attrs = []
      until peek_type?(:lbrace) || peek_type?(:eof)
        unless %i[ident keyword].include?(peek&.type) && peek(1)&.type == :assign
          add_parse_error(
            rule: "OOF-FORM0",
            message: "form invocation '#{trigger}' attributes must use key=value before the child block",
            token: peek&.value.to_s,
            line: peek&.line || 0,
            col: peek&.col || 0
          )
          break
        end
        name = advance.value
        expect_type!(:assign)
        attrs << { "name" => name, "value" => parse_expr }
        advance if peek_type?(:comma)
      end

      expect_type!(:lbrace)
      children = []
      until peek_type?(:rbrace) || peek_type?(:eof)
        children << parse_expr
        advance if peek_type?(:comma)
      end
      expect_type!(:rbrace)
      { "kind" => "form_invocation", "trigger" => trigger, "attrs" => attrs, "children" => children }
    end

    # Shared guard for block-header positions (`if` conditions, `match`
    # subjects): while active, a bare ident before `{` stays a plain ref
    # instead of opening a Gap-I form invocation.
    def suppress_form_invocation
      @form_guard_depth = (@form_guard_depth || 0) + 1
      begin
        yield
      ensure
        @form_guard_depth -= 1
      end
    end

    def parse_if_expr
      # LANG-RUBY-IF-COND-BARE-IDENT-FORM-GUARD-P1: suppress form-invocation
      # detection while parsing the condition so its `{` opens the then-block.
      cond = suppress_form_invocation { parse_expr }
      then_block = parse_block_body
      else_block = nil
      if peek_kw?("else")
        advance
        else_block =
          if peek_kw?("if")
            # LAB-IGNITER-ELSE-IF-CHAINING-IMPL-P1: `else if` is source-surface sugar.
            # Desugar to the existing nested form `else { if ... }` by parsing the
            # trailing `if` as the else branch's sole return expression — the AST is
            # byte-identical to the hand-written nesting, so no new node kind, no new
            # diagnostics: the innermost `if` keeps its own required-else obligation.
            # LL(1)-clean: after `else`, `if` can never open a block (blocks start `{`).
            advance
            { "stmts" => [], "return_expr" => parse_if_expr }
          else
            parse_block_body
          end
      end
      { "kind" => "if_expr", "cond" => cond, "then" => then_block, "else" => else_block }
    end

    def parse_array_literal
      expect_type!(:lbracket)
      items = []
      until peek_type?(:rbracket) || peek_type?(:eof)
        items << parse_expr
        advance if peek_type?(:comma)
      end
      expect_type!(:rbracket)
      { "kind" => "array_literal", "items" => items }
    end

    # ── PROP-044-P3: variant declaration ──────────────────────────────────────

    def parse_variant_decl
      name = name_token!(%i[ident])
      expect_type!(:lbrace)
      arms = []
      until peek_type?(:rbrace) || peek_type?(:eof)
        arm = parse_variant_arm
        arms << arm if arm
      end
      expect_type!(:rbrace)
      { "kind" => "variant", "name" => name, "arms" => arms }
    end

    def parse_variant_arm
      arm_name = name_token!(%i[ident])
      fields = []
      if peek_type?(:lbrace)
        advance # consume {
        until peek_type?(:rbrace) || peek_type?(:eof)
          fname = name_token!(%i[ident keyword])
          expect_type!(:colon)
          ftype = parse_type_ref
          fields << { "name" => fname, "type_annotation" => ftype }
          advance if peek_type?(:comma)
        end
        expect_type!(:rbrace)
      end
      advance if peek_type?(:comma)
      { "kind" => "variant_arm", "name" => arm_name, "fields" => fields }
    end

    # ── PROP-044-P3: variant construct expression ──────────────────────────

    def parse_variant_construct(arm_name)
      expect_type!(:lbrace)
      fields = {}
      until peek_type?(:rbrace) || peek_type?(:eof)
        key = name_token!(%i[ident keyword])
        expect_type!(:colon)
        val = parse_expr
        fields[key] = val
        advance if peek_type?(:comma)
      end
      expect_type!(:rbrace)
      { "kind" => "variant_construct", "arm" => arm_name, "fields" => fields }
    end

    # ── PROP-044-P3: match expression ─────────────────────────────────────

    def parse_match_expr
      # LANG-RUBY-VARIANT-MATCH-PARSER-P1: the subject parses under the form
      # guard so `match v {` keeps `v` a plain ref — without it the `{` of the
      # match body was claimed as a Gap-I form invocation and the first arm
      # (`A { x } =>`) crashed variant-construct parsing with an uncaught
      # "Expected colon, got rbrace" (IGDB-P23).
      subject =
        begin
          suppress_form_invocation { parse_expr }
        rescue ParseError => e
          record_match_parse_failure(e, "match subject")
          recover_past_match_header
          return { "kind" => "error", "token" => "match" }
        end

      unless peek_type?(:lbrace)
        tok = peek
        add_parse_error(
          rule: "OOF-P0",
          message: "Expected '{' to open match body, got #{tok&.type}(#{tok&.value})",
          token: tok&.value.to_s,
          line: tok&.line || 0,
          col: tok&.col || 0
        )
        recover_past_match_header
        return { "kind" => "error", "token" => "match" }
      end
      advance # consume {

      # Fail-closed recovery anchor: locate the `}` closing the match body by
      # balanced scan BEFORE arm parsing, so a malformed arm becomes a recorded
      # parse error plus a clean skip to the end of the match — never an
      # uncaught ParseError (the IGDB-P23 crash class).
      close_pos = matching_rbrace_pos

      arms = []
      until peek.nil? || peek_type?(:rbrace) || peek_type?(:eof)
        begin
          arm = parse_match_arm
          arms << arm if arm
        rescue ParseError => e
          record_match_parse_failure(e, "match arm")
          @pos = close_pos || (@tokens.length - 1)
          break
        end
        advance if peek_type?(:comma)
      end

      if peek_type?(:rbrace)
        advance
      else
        tok = peek
        add_parse_error(
          rule: "OOF-P0",
          message: "Unterminated match body",
          token: tok&.value.to_s,
          line: tok&.line || 0,
          col: tok&.col || 0
        )
      end
      { "kind" => "match_expr", "subject" => subject, "arms" => arms }
    end

    def record_match_parse_failure(err, where)
      add_parse_error(
        rule: "OOF-P0",
        message: "Malformed #{where}: #{err.message}",
        token: peek&.value.to_s,
        line: err.line || peek&.line || 0,
        col: err.col || peek&.col || 0
      )
    end

    # After a failed match header (bad subject or missing `{`), skip forward to
    # the body block if one follows and consume it whole, so the enclosing
    # declaration can resynchronize on its own boundaries.
    def recover_past_match_header
      until peek_type?(:eof) || peek_type?(:lbrace) || peek_type?(:rbrace) || body_boundary_token?(peek)
        advance
      end
      skip_balanced_block if peek_type?(:lbrace)
    end

    # Index of the `}` that closes the currently-open brace (assumes the `{`
    # was just consumed, i.e. depth starts at 1). Returns nil when unbalanced.
    def matching_rbrace_pos
      depth = 1
      idx = @pos
      while (tok = @tokens[idx]) && tok.type != :eof
        depth += 1 if tok.type == :lbrace
        if tok.type == :rbrace
          depth -= 1
          return idx if depth.zero?
        end
        idx += 1
      end
      nil
    end

    def parse_match_arm
      pattern = parse_match_pattern
      return nil unless pattern
      expect_type!(:fat_arrow)
      body = parse_expr
      { "kind" => "match_arm", "pattern" => pattern, "body" => body }
    end

    def parse_match_pattern
      tok = peek
      return nil if tok.nil? # fail-closed: truncated stream (past eof)
      if tok.type == :ident && tok.value == "_"
        advance
        return { "wildcard" => true, "arm" => "_", "bindings" => [] }
      end
      if tok.type == :ident || tok.type == :keyword
        arm_name = name_token!(%i[ident keyword])
        bindings = []
        if peek_type?(:lbrace)
          advance # consume {
          until peek_type?(:rbrace) || peek_type?(:eof)
            binding = name_token!(%i[ident keyword])
            bindings << binding
            advance if peek_type?(:comma)
          end
          expect_type!(:rbrace)
        end
        return { "wildcard" => false, "arm" => arm_name, "bindings" => bindings }
      end
      @errors << { "message" => "Expected match arm pattern, got #{tok.type}(#{tok.value})", "line" => tok.line }
      advance
      nil
    end

    def parse_record_or_block
      # { key: value, ... } — record literal
      expect_type!(:lbrace)
      fields = {}
      until peek_type?(:rbrace) || peek_type?(:eof)
        key_tok = peek
        key = name_token!(%i[ident keyword])
        # LANG-RECORD-FIELD-PUNNING-CANON-PARITY-P1: a field with no `:` is punned —
        # `{ name }` ⇒ `{ name: name }` (also mixed `{ name, other: expr }`). Desugars
        # immediately to the canonical ref value, so the record literal sees the same
        # `{ name: <ref> }` shape as the explicit form — no new AST/SIR node. Mirrors
        # Rust parse_record_or_block (igniter-compiler src/parser.rs, LAB-LANG-RECORD-
        # FIELD-PUNNING-P2). Dotted punning (`{ a.b }`) stays closed: after the punned
        # `a` the `.` is not a comma/rbrace, so the next name_token! fails closed with
        # the same "Expected name, got dot" parse diagnostic Rust raises.
        val =
          if peek_type?(:colon)
            advance
            parse_expr
          else
            { "kind" => "ref", "name" => key }
          end
        # Duplicate fields fail closed (no last-write-wins) — same rule and message as
        # Rust parse_record_or_block; punned and explicit fields share this guard.
        if fields.key?(key)
          raise ParseError.new("duplicate field `#{key}` in record literal", key_tok.line, key_tok.col)
        end
        fields[key] = val
        advance if peek_type?(:comma)
      end
      expect_type!(:rbrace)
      { "kind" => "record_literal", "fields" => fields }
    end
  end

  # ---------------------------------------------------------------------------
  # ParsedProgram builder (public API)
  # ---------------------------------------------------------------------------
  class ParsedProgram
    attr_reader :ast, :source_hash, :errors

    def self.parse(source, source_path: "<stdin>")
      require "digest"
      tokens = Lexer.new(source).tokenize
      parser = Parser.new(tokens)
      ast    = parser.parse
      new(ast: ast, source: source, source_path: source_path)
    end

    def initialize(ast:, source:, source_path:)
      require "digest"
      @ast         = ast
      @source_path = source_path
      @source_hash = "sha256:#{Digest::SHA256.hexdigest(source)}"
      @errors      = ast.fetch("parse_errors", [])
    end

    def valid?
      @errors.empty?
    end

    def to_json(**opts)
      JSON.generate(to_h, **opts)
    end

    def to_h
      {
        "kind"            => "parsed_program",
        "source_path"     => @source_path,
        "source_hash"     => @source_hash,
        "grammar_version" => grammar_version,
        "module"          => @ast["module"],
        "imports"         => @ast["imports"],
        "traits"          => @ast["traits"],
        "impls"           => @ast["impls"],
        "contract_shapes" => @ast["contract_shapes"],
        "contracts"       => @ast["contracts"],
        "types"           => @ast["types"],
        "variants"        => @ast.fetch("variants", []),         # PROP-044-P3
        "functions"       => @ast["functions"],
        "consts"          => @ast.fetch("consts", []),
        "pipelines"       => @ast.fetch("pipelines", []),
        "olap_points"     => @ast.fetch("olap_points", []),
        "assumptions"     => @ast.fetch("assumptions", []),
        "profiles"        => @ast.fetch("profiles", []),        # PROP-040
        "size_relations"  => @ast.fetch("size_relations", []),  # PROP-041
        "entrypoint"      => @ast.fetch("entrypoint", nil),     # PROP-ENTRYPOINT-P3
        "intent_text"     => @ast.fetch("intent_text", nil),    # PROP-045
        "parse_errors"    => @errors
      }
    end

    def grammar_version
      decimal_type_ref = lambda { |n|
        n.is_a?(Hash) && n["kind"] == "type_ref" && n["name"] == "Decimal"
      }
      return "assumptions-v0" if @ast.fetch("assumptions", []).any? ||
                                 @ast.fetch("contracts", []).any? { |c|
                                   c.fetch("body", []).any? { |n| n.is_a?(Hash) && n["kind"] == "uses_assumptions" }
                                 }
      return "olap-point-v0" if @ast.fetch("olap_points", []).any?

      has_decimal = @ast.fetch("contracts", []).any? { |c|
        c.fetch("body", []).any? { |node|
          node.is_a?(Hash) && (
            decimal_type_ref.call(node["type_annotation"]) ||
            decimal_type_ref.call(node.fetch("type_annotation", nil))
          )
        }
      } || @ast.fetch("types", []).any? { |t| decimal_type_ref.call(t["alias"]) }
      return "decimal-v0" if has_decimal

      return "spark-pipeline-v0" if @ast.fetch("pipelines", []).any? ||
                                    @ast.fetch("contracts", []).any? { |c|
                                      c.fetch("body", []).any? { |n|
                                        n.is_a?(Hash) && n["scoped_by"]
                                      }
                                    }

      return "polymorphic-v0" if @ast.fetch("traits", []).any? ||
                                 @ast.fetch("impls", []).any? ||
                                 @ast.fetch("contract_shapes", []).any? ||
                                 @ast.fetch("contracts", []).any? { |contract| contract.fetch("type_params", []).any? }

      # PROP-040: profile declarations
      return "profile-v0" if @ast.fetch("profiles", []).any?

      # PROP-044-P3: variant declarations and match/variant_construct expressions
      has_variant_forms = @ast.fetch("variants", []).any? ||
        @ast.fetch("contracts", []).any? { |c|
          c.fetch("body", []).any? { |n|
            next false unless n.is_a?(Hash)
            expr = n["expr"]
            expr.is_a?(Hash) && %w[match_expr variant_construct].include?(expr["kind"])
          }
        }
      return "variant-v0" if has_variant_forms

      # PROP-039 gate 3: loop/recursion forms
      loop_contract_modifiers = %w[recursive fuel_bounded]
      loop_body_kinds = %w[for_loop budgeted_loop decreases max_steps]
      has_loop_forms = @ast.fetch("contracts", []).any? { |c|
        loop_contract_modifiers.include?(c["modifier"]) ||
          c.fetch("body", []).any? { |n| n.is_a?(Hash) && loop_body_kinds.include?(n["kind"]) }
      }
      return "loop-v0" if has_loop_forms

      "0.1.0"
    end
  end
end
