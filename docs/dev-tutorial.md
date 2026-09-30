# Igniter: First Programs

Status: bounded tutorial; examples rechecked 2026-09-30.

Igniter makes contracts the unit of a program. A **pure** contract transforms
inputs into a value; observed and effectful contracts have additional rules
for interacting with the world. This introduction starts with pure computation.
It does not describe every language feature or certify every application.

Each code block below is a complete, separate source file. The positive examples
were checked by the Ruby and Rust frontends and executed through the Lab Standard
Runtime. Dual source acceptance alone does not prove identical artifacts or
runtime behavior. See the [Lab learning path](../../igniter-lab/lab-docs/tutorial/README.md)
for commands, tool prerequisites and the dated verification record.

## 1. A Contract And Its Entry

```igniter title="hello.ig"
module Tutorial.Hello

pure contract Double(n: Integer) -> (result: Integer) = n + n

pure contract Main {
  compute result = Double(21)
  output result: Integer
}

entrypoint Main
```

Result: `42`. `Double(21)` is a statically resolved pure-contract call.
`call_contract("Double", 21)` is the explicit spelling; a runtime string is not
a general dynamic dispatcher. `entrypoint Main` selects the default contract;
it does not execute it during compilation.

The signature/expression form is shorthand for declared inputs, a compute
binding and one named output. `compute` names a graph value, not mutable state.
A value-returning contract has one output; use a record for several fields.

From the Lab checkout, for a file at `hello.ig`:

```sh
bin/igniter source check hello.ig --toolchain both --json
bin/igniter run hello.ig
```

The first command checks source without emitting an artifact. The second
compiles and activates one entry using the maintained compiler/runtime pair.
Neither command builds missing tools automatically.

## 2. Numbers And Math

```igniter title="numbers.ig"
module Tutorial.Numbers

pure contract Main {
  compute result = sqrt(9.0) + abs(0.0 - 2.0)
  output result: Float
}

entrypoint Main
```

Result: `5.0`. **Float exists**; floating literals such as `9.0` are not Decimal.
`Integer`, `Float` and scale-aware `Decimal[N]` have distinct arithmetic rules.
There is no implicit Integer/Float/Decimal conversion. `sqrt` takes a Float;
scalar `abs` supports Integer or Float. See [math and numeric boundaries](spec/ch8-stdlib.md).

Fixed-point Integer is an application choice, not a workaround for missing
floating-point support. Decimal has an explicit construction API and is useful
when a decimal scale matters. Floating-point arithmetic is not exact real
arithmetic; not every math operation has a cross-platform bitwise guarantee.

This deliberately invalid program mixes numeric families:

```igniter title="mixed-numbers.ig"
module Tutorial.MixedNumbers
pure contract Main {
  compute result = 1 + 2.0
  output result: Float
}
entrypoint Main
```

Source checking refuses it with `OOF-TY0`. Refusal is the expected result, not a
request to coerce or silently change the expression.

## 3. Records And Branches

```igniter title="records.ig"
module Tutorial.Records
type Reading { value: Integer, valid: Bool }

pure contract Main {
  compute reading: Reading = if true {
    { value: 7, valid: true }
  } else {
    { value: 0, valid: false }
  }
  compute result = reading.value
  output result: Integer
}

entrypoint Main
```

Result: `7`. Records in branches are supported; a factory contract is not
generally required to read their fields. Record naming depends on declared
shapes and type context. Ambiguous or unnamed record families still have
restrictions; consult the [type-system rules](spec/ch3-type-system.md).

`if` is an expression and requires `else`. Fields with same-named bindings can
be punned (`{ value, valid }`). Use a space after `:` in examples to avoid
confusing a field value with a Symbol literal.

## 4. Collections And Local Functions

```igniter title="collections.ig"
module Tutorial.Collections

def twice(x: Integer) -> Integer { x + x }

pure contract Main {
  compute doubled = map([1, 2, 3], x -> twice(x))
  compute result = fold(doubled, 0, (acc, x) -> acc + x)
  output result: Integer
}

entrypoint Main
```

Result: `12`. `map` transforms elements; `fold` combines them with an explicit
seed. A `def` is a typed local function, not a second contract or an IO escape.
Lambda types come from their collection and accumulator context.

Collection joins reject incompatible known element families. Empty collections
and open types have their own rules; successful inference in one example is
not permission to mix unrelated types. `fold_stream` has separate callable and
resource rules; this ordinary `fold` example does not qualify stream behavior.

## 5. Option And Match

```igniter title="option.ig"
module Tutorial.Option

pure contract Main {
  compute chosen = first([7, 8])
  compute result = match chosen {
    Some { value } => value
    None => 0
  }
  output result: Integer
}

entrypoint Main
```

Result: `7`. `first` returns `Option[T]`; an empty collection produces `None`.
Option and Result are matchable sealed families, not ordinary records.
Source construction uses `some(value)`, `none()`, `ok(value)` and `err(error)`;
PascalCase arm patterns are not constructor syntax.

`or_else(chosen, 0)` or `unwrap_or(chosen, 0)` is a simpler fallback when no
branch-specific behavior is needed. A record does not become an Option because
its keys resemble the internal carrier. User-defined variants use `variant`
declarations and exhaustive `match`; qualified `Variant::Arm` disambiguates arms.

## 6. Profiles Do Not Grant Host Authority

```igniter title="profile.ig"
module Tutorial.Profile
profile Calculation { authority: pure }

pure contract Main via Calculation {
  compute result = 42
  output result: Integer
}

entrypoint Main
```

Result: `42`. Profile declarations and `via` are supported by both frontends.
They express compile-time restrictions, not host credentials or permission to
perform an effect. The [profile chapter](spec/ch11-profile-system.md) names the
accepted policy checks and the still-unimplemented obligations separately.

Observed, effect, privileged and irreversible contracts are not all pure.
Effectful composition uses `invoke ... using ...`; a successful compile does
not supply the operator binding, adapter or external system. Those belong to
the runtime/host boundary. See [contract modifiers](spec/ch10-contract-modifiers.md)
and [effects](spec/ch12-effect-surface.md) before introducing IO.

## What To Learn Next

- [Source surface](spec/ch2-source-surface.md): declarations, calls, branches,
  records, constructors, functions and operators.
- [Type system](spec/ch3-type-system.md): named records, variants, collection
  joins and error propagation.
- [Stdlib](spec/ch8-stdlib.md): admitted signatures and their individual limits.
- [Managed recursion](spec/ch13-managed-recursion.md): explicit loop classes and
  bounds; not a blanket guarantee of termination or realtime response.

Do not use an old absence list as a current language reference. Vocabulary,
entity syntax and a proposed contract-composition algebra need their own
admission; ordinary contracts and explicit state already support many examples.
The [Covenant](language-covenant.md) gives design commitments, not proof that
every compiler, host or application implements every commitment.
