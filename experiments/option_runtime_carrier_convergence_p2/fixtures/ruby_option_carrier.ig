module Option.Carrier

type Payload {
  __arm : Text
  __variant : Text
  value : Integer
}

type Envelope {
  direct : Option[Payload]
  nested : Option[Option[Integer]]
  values : Collection[Option[Integer]]
}

type OptionalRow {
  label : Text
  note : Text?
}

pure contract Build {
  input n : Integer
  input label : Text

  compute payload : Payload = { __arm: label, __variant: label, value: n }
  compute direct : Option[Payload] = some(payload)
  compute nested : Option[Option[Integer]] = some(some(n))
  compute values : Collection[Option[Integer]] = [some(n), none()]
  compute result : Envelope = { direct: direct, nested: nested, values: values }

  output result : Envelope
}

pure contract Branch {
  input n : Integer
  compute result : Option[Integer] = if true { some(n) } else { none() }
  output result : Option[Integer]
}

pure contract NestedSomeNone {
  compute result : Option[Option[Integer]] = some(none())
  output result : Option[Option[Integer]]
}

pure contract FilterMap {
  input values : Collection[Integer]
  compute result : Collection[Integer] = filter_map(values, value -> some(value))
  output result : Collection[Integer]
}

pure contract CollectionMap {
  input values : Collection[Integer]
  compute result : Collection[Integer] = map(values, value -> value)
  output result : Collection[Integer]
}

pure contract CollectionFlatMap {
  input values : Collection[Collection[Integer]]
  compute result : Collection[Integer] = flat_map(values, value -> value)
  output result : Collection[Integer]
}

observed contract NestedHistoryAt {
  input model_key : Text
  input points : Collection[DateTime]

  escape history_read

  read prediction_history: History[Integer]
    from "predictor/{model_key}"
    lifecycle :durable

  compute result : Collection[Option[Integer]] =
    map(points, point -> history_at(prediction_history, point))

  output result : Collection[Option[Integer]]
}

pure contract Match {
  input value : Option[Integer]
  compute result : Integer = match value {
    Some { value } => value
    None { } => 0
  }
  output result : Integer
}

pure contract NestedMatch {
  input value : Option[Option[Integer]]
  compute result : Integer = match value {
    Some { value } => match value {
      Some { value } => value
      None { } => 0
    }
    None { } => 0
  }
  output result : Integer
}

pure contract Fallback {
  input value : Option[Integer]
  compute result : Integer = unwrap_or(value, 0)
  output result : Integer
}

pure contract SourceFallback {
  input n : Integer
  compute result : Integer = or_else(some(n), 0)
  output result : Integer
}

pure contract PredicateSome {
  input n : Integer
  compute result : Bool = is_some(some(n))
  output result : Bool
}

pure contract PredicateNone {
  compute result : Bool = is_none(none())
  output result : Bool
}

pure contract OptionMap {
  input n : Integer
  compute result : Option[Integer] = map(some(n), value -> value)
  output result : Option[Integer]
}

pure contract OptionFlatMap {
  input n : Integer
  compute result : Option[Integer] = flat_map(some(n), value -> some(value))
  output result : Option[Integer]
}

pure contract OptionAndThen {
  input n : Integer
  compute result : Option[Integer] = and_then(some(n), value -> some(value))
  output result : Option[Integer]
}

pure contract ResultFallback {
  input n : Integer
  compute value : Result[Integer, Text] = ok(n)
  compute result : Integer = unwrap_or(value, 0)
  output result : Integer
}

pure contract ResultMap {
  input n : Integer
  compute value : Result[Integer, Text] = ok(n)
  compute result : Result[Integer, Text] = map(value, item -> item)
  output result : Result[Integer, Text]
}

pure contract ResultAndThen {
  input n : Integer
  compute value : Result[Integer, Text] = ok(n)
  compute result : Result[Integer, Text] = and_then(value, item -> ok(item))
  output result : Result[Integer, Text]
}

pure contract OptionalOmitted {
  input label : Text
  compute result : OptionalRow = { label: label }
  output result : OptionalRow
}

pure contract OptionalRaw {
  input label : Text
  compute result : OptionalRow = { label: label, note: label }
  output result : OptionalRow
}

pure contract OptionalPresent {
  input label : Text
  compute note : Option[Text] = some(label)
  compute result : OptionalRow = { label: label, note: note }
  output result : OptionalRow
}
