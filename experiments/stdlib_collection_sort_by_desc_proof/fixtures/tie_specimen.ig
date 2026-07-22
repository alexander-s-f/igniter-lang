module SortByDescTieSpecimen

-- LANG-STDLIB-COLLECTION-SORT-BY-DESC-P2: the §8.14.2 duplicate-key tie specimen, kept as a
-- DURABLE HANDOFF FIXTURE for P3 (Rust/VM execution). At P2 this file proves only that the
-- specimen is ACCEPTED and lowered with the correct element/key shapes (fn =
-- stdlib.collection.sort_by_desc, elements stay Item, keys Integer). It makes NO runtime-order
-- claim — that is P3's to prove on the VM.
--
-- Expected §8.14.2 runtime result, to be asserted by P3 and ONLY by P3:
--   keys = [10, 10, 7, 5, 5]
--   seqs = [1, 3, 5, 2, 4]     -- ties preserve authored/input order (seq 1 before 3, 2 before 4);
--                              -- an element-reversal of ascending sort_by would yield [3,1,5,4,2].

type Item {
  key : Integer,
  seq : Integer
}

type TieOut {
  keys : Collection[Integer],
  seqs : Collection[Integer]
}

pure contract RunTieSpecimen {
  compute i1 : Item = { key: 10, seq: 1 }
  compute i2 : Item = { key: 5,  seq: 2 }
  compute i3 : Item = { key: 10, seq: 3 }
  compute i4 : Item = { key: 5,  seq: 4 }
  compute i5 : Item = { key: 7,  seq: 5 }
  compute items : Collection[Item] = [i1, i2, i3, i4, i5]
  compute sorted : Collection[Item] = sort_by_desc(items, x -> x.key)
  compute keys : Collection[Integer] = map(sorted, x -> x.key)
  compute seqs : Collection[Integer] = map(sorted, x -> x.seq)
  compute out : TieOut = { keys: keys, seqs: seqs }
  output out : TieOut
}
