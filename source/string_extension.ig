-- string_extension.ig
-- Text stdlib surface (stdlib.text.*) — experiment-pass 2026-06-08.
-- Supersedes: StringWorkflow (PROP-013 string.ig surface, legacy/held).
-- Canonical type: Text. Old `String` type and ambiguous `length` are legacy.
-- See: igniter-lang/docs/spec/ch8-stdlib.md §8.10

module SparkCRM.StringExtensions

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

  output joined: Text
  output clean: Text
  output has_other: Bool
  output starts: Bool
  output ends_val: Bool
  output parts: Collection[Text]
  output replaced: Text
  output replaced_all: Text
  output byte_count: Integer
  output rune_count: Integer
  output grapheme_count: Integer
  output byte_part: Text
  output rune_part: Text
  output grapheme_part: Text
}
