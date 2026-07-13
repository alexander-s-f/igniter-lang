-- string_extension.ig
-- Text stdlib surface (stdlib.text.*) — experiment-pass 2026-06-08.
-- Supersedes: StringWorkflow (PROP-013 string.ig surface, legacy/held).
-- Canonical type: Text. Old `String` type and ambiguous `length` are legacy.
-- See: igniter-lang/docs/spec/ch8-stdlib.md §8.10

module SparkCRM.StringExtensions
-- LANG-CONTRACT-SINGLE-OUTPUT-LAW-P2: named result record (one value per contract)
type TextWorkflowResult { joined : Text, clean : Text, has_other : Bool, starts : Bool, ends_val : Bool, parts : Collection[Text], replaced : Text, replaced_all : Text, byte_count : Integer, rune_count : Integer, grapheme_count : Integer, byte_part : Text, rune_part : Text, grapheme_part : Text }


pure contract TextWorkflow {
  input text: Text
  input other: Text
  input delimiter: Text
  input pattern: Text
  input replacement: Text
  input start: Integer
  input end_idx: Integer

  -- basic composition
  compute joined: Text = concat(text, other)
  compute clean: Text = trim(text)

  -- predicates
  compute has_other: Bool = contains(text, other)
  compute starts: Bool = starts_with(text, other)
  compute ends_val: Bool = ends_with(text, other)

  -- structural ops
  compute parts: Collection[Text] = split(text, delimiter)
  compute replaced: Text = replace(text, pattern, replacement)
  compute replaced_all: Text = replace_all(text, pattern, replacement)

  -- explicit unit-qualified lengths (replaces legacy ambiguous `length`)
  compute byte_count: Integer = byte_length(text)
  compute rune_count: Integer = rune_length(text)
  compute grapheme_count: Integer = grapheme_length(text)

  -- explicit unit-qualified slices
  compute byte_part: Text = byte_slice(text, start, end_idx)
  compute rune_part: Text = rune_slice(text, start, end_idx)
  compute grapheme_part: Text = grapheme_slice(text, start, end_idx)

  compute result : TextWorkflowResult = { joined: joined, clean: clean, has_other: has_other, starts: starts, ends_val: ends_val, parts: parts, replaced: replaced, replaced_all: replaced_all, byte_count: byte_count, rune_count: rune_count, grapheme_count: grapheme_count, byte_part: byte_part, rune_part: rune_part, grapheme_part: grapheme_part }

  output result : TextWorkflowResult
}
