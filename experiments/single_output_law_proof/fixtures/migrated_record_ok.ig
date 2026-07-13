module LawMigrated

type TwoOutResult { x : Integer, y : Integer }

contract TwoOut {
  input a : Integer
  compute x = a + 1
  compute y = a + 2
  compute result : TwoOutResult = { x: x, y: y }
  output result : TwoOutResult
}
