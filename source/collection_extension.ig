-- collection_extension.ig
-- Conformance fixture verifying find, any, all, and collection concat.

module SparkCRM.CollectionExtensions

type Item {
  id: Integer,
  value: Integer
}
-- LANG-CONTRACT-SINGLE-OUTPUT-LAW-P2: named result record (one value per contract)
type CollectionWorkflowResult { found : Option[Item], has_any : Bool, all_pos : Bool, merged_count : Integer }


contract CollectionWorkflow {
  input items: Collection[Item]
  input threshold: Integer
  input extra: Collection[Item]

  -- find: first item with value > threshold (returns Option[Item])
  compute found = find(items, i -> i.value > threshold)

  -- any: does any item have value > threshold?
  compute has_any = any(items, i -> i.value > threshold)

  -- all: do all items have value > 0?
  compute all_pos = all(items, i -> i.value > 0)

  -- concat: join items and extra into one collection
  compute merged = concat(items, extra)
  compute merged_count = count(merged)

  compute result : CollectionWorkflowResult = { found: found, has_any: has_any, all_pos: all_pos, merged_count: merged_count }

  output result : CollectionWorkflowResult
}
