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
    dot dot_dot comma colon double_colon dot_dot_dot arrow fat_arrow
    op assign pipe question bang
    newline eof comment
  ].freeze

  Token = Struct.new(:type, :value, :line, :col)

  # ---------------------------------------------------------------------------
  # Lexer
  # ---------------------------------------------------------------------------
  KEYWORDS = %w[
    module import contract contract_shape type def trait impl
    input output compute read snapshot window escape
    stream fold_stream
    assumptions assumption uses
    olap_point
    invariant predicate severity label message overridable_with
    from lifecycle using implements
    pipeline step scoped_by cardinality schema_version tenant_free
    if else let
    true false nil
    and or not
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
      when /[a-zA-Z_]/ then read_ident_or_keyword(l, c)
      else
        advance
        nil
      end
    end

    def read_string(l, c)
      advance # consume opening "
      buf = +""
      until peek == '"' || @pos >= @source.length
        buf << advance
      end
      advance # consume closing "
      Token.new(:string_lit, buf, l, c)
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
                  "contracts" => [], "types" => [], "functions" => [],
                  "pipelines" => [], "olap_points" => [], "assumptions" => [],
                  "parse_errors" => [] }

      # optional module declaration
      if peek_kw?("module")
        advance
        program["module"] = parse_module_path
      end

      # imports
      while peek_kw?("import")
        advance
        program["imports"] << parse_import
      end

      # top-level declarations
      until peek_type?(:eof)
        decl = parse_top_decl
        case decl&.fetch("kind")
        when "trait"          then program["traits"]          << decl
        when "impl"           then program["impls"]           << decl
        when "contract_shape" then program["contract_shapes"] << decl
        when "contract"       then program["contracts"]       << decl
        when "type"           then program["types"]           << decl
        when "function"       then program["functions"]       << decl
        when "pipeline"       then program["pipelines"]       << decl
        when "olap_point"     then program["olap_points"]     << decl
        when "assumptions"    then program["assumptions"].concat(decl.fetch("assumptions", []))
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

    CONTRACT_MODIFIERS = %w[pure observed effect privileged irreversible].freeze

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
      when "def"            then advance; parse_function_decl
      when "pipeline"       then advance; parse_pipeline_decl
      when "olap_point"     then advance; parse_olap_point_decl
      when "assumptions"    then advance; parse_assumptions_block
      else
        @errors << { "message" => "Unexpected token: #{tok.value}", "line" => tok.line }
        advance
        nil
      end
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
      expect_type!(:lbrace)
      body = []
      until peek_type?(:rbrace) || peek_type?(:eof)
        body << parse_body_decl
      end
      expect_type!(:rbrace)
      node = { "kind" => "contract", "name" => name, "modifier" => modifier || "pure", "type_params" => type_params }
      node["implements"] = implements if implements
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
      when "escape"   then advance; parse_escape_decl
      when "stream"   then advance; parse_stream_decl
      when "fold_stream" then advance; parse_fold_stream_decl
      when "invariant"   then advance; parse_invariant_decl
      when "uses"        then advance; parse_uses_decl
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
      name = name_token!(%i[ident])
      expect_type!(:colon)
      type_ref = parse_type_ref
      { "kind" => "input", "name" => name, "type_annotation" => type_ref }
    end

    def parse_output_decl
      name = name_token!(%i[ident])
      expect_type!(:colon)
      type_ref = parse_type_ref
      lifecycle = peek_kw?("lifecycle") ? (advance; parse_lifecycle) : nil
      node = { "kind" => "output", "name" => name, "type_annotation" => type_ref }
      node["lifecycle"] = lifecycle if lifecycle
      node["evidence"] = parse_evidence_list if peek_value?("evidence")
      node
    end

    def parse_uses_decl
      tok = peek
      unless peek_kw?("assumptions")
        add_parse_error(
          rule: "OOF-P0",
          message: "uses declaration currently supports only 'uses assumptions NAME'",
          token: tok&.value.to_s,
          line: tok&.line || 0,
          col: tok&.col || 0
        )
        skip_until_body_boundary
        return nil
      end
      advance
      name = name_token!(%i[ident])
      { "kind" => "uses_assumptions", "name" => name }
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

    def parse_compute_decl
      name = name_token!(%i[ident])
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
      body = parse_block_body
      { "kind" => "function", "name" => name, "params" => params,
        "return_type" => return_type, "body" => body }
    end

    def parse_params
      expect_type!(:lparen)
      params = []
      until peek_type?(:rparen) || peek_type?(:eof)
        pname = name_token!(%i[ident])
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
      name = name_token!(%i[ident])
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
        elsif peek_type?(:lparen) && expr["kind"] == "ref"
          # function call: name(args)
          fn_name = expr["name"]
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
      elsif peek_type?(:ident) && peek(1)&.type == :arrow
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
          pname = name_token!(%i[ident])
          params << pname
          advance if peek_type?(:comma)
        end
        expect_type!(:rparen)
      elsif peek_type?(:ident)
        params << advance.value
      end
      expect_type!(:arrow)
      body = peek_type?(:lbrace) ? parse_lambda_block : parse_expr
      { "kind" => "lambda", "params" => params, "body" => body }
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
        when "true"  then advance; { "kind" => "literal", "value" => true,  "type_tag" => "Bool" }
        when "false" then advance; { "kind" => "literal", "value" => false, "type_tag" => "Bool" }
        when "nil"   then advance; { "kind" => "literal", "value" => nil,   "type_tag" => "Nil" }
        else
          advance; { "kind" => "ref", "name" => tok.value }
        end
      when :ident
        advance; { "kind" => "ref", "name" => tok.value }
      when :int_lit
        advance; { "kind" => "literal", "value" => tok.value, "type_tag" => "Integer" }
      when :float_lit
        advance; { "kind" => "literal", "value" => tok.value, "type_tag" => "Float" }
      when :string_lit
        advance; { "kind" => "literal", "value" => tok.value, "type_tag" => "String" }
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
        advance
        { "kind" => "error", "token" => tok.value }
      end
    end

    def parse_if_expr
      cond = parse_expr
      then_block = parse_block_body
      else_block = nil
      if peek_kw?("else")
        advance
        else_block = parse_block_body
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

    def parse_record_or_block
      # { key: value, ... } — record literal
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
        "functions"       => @ast["functions"],
        "pipelines"       => @ast.fetch("pipelines", []),
        "olap_points"     => @ast.fetch("olap_points", []),
        "assumptions"     => @ast.fetch("assumptions", []),
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

      "0.1.0"
    end
  end
end
