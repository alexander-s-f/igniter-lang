module R15.UI

type Rec { id : String name : String hot : Bool }
type Item { id : String label : String action : String key : String selected : Bool }
type Prim { id : String kind : String x1 : Integer y1 : Integer x2 : Integer y2 : Integer color : Integer text : String }
type Layout { y : Integer prims : Collection[Prim] }
type AppView { status : String choices : Collection[Item] canvas : Collection[Prim] }

pure contract Button {
  input id : String input label : String input key : String input selected : Bool
  compute item : Item = { id: id, label: label, action: "select", key: key, selected: selected }
  output item : Item
}
pure contract Card {
  input id : String input y : Integer input color : Integer
  compute prim : Prim = { id: "card:${id}", kind: "rect", x1: 20, y1: y, x2: 380, y2: y + 46, color: color, text: "" }
  output prim : Prim
}
pure contract Label {
  input id : String input y : Integer input text : String
  compute prim : Prim = { id: "label:${id}", kind: "text", x1: 34, y1: y, x2: 34, y2: y, color: 15003638, text: text }
  output prim : Prim
}
pure contract Step {
  input y : Integer input prims : Collection[Prim]
  compute next : Layout = { y: y, prims: prims }
  output next : Layout
}

pure contract View {
  input records : Collection[Rec]
  input selected : String
  input top : Integer

  compute gap : Integer = 60
  compute choices : Collection[Item] = map(records, (r) -> {
      let label = "${r.name} / ${r.id}"
      let chosen = r.id == selected
      Button(r.id, label, r.id, chosen)
    })
  compute seed : Layout = Step(top, [])
  compute laid : Layout = fold(records, seed, (acc, r) -> {
      let y = acc.y
      let color = if r.id == selected { 2635336 } else { 1715511 }
      let title = if r.hot { "${r.name} (hot)" } else { r.name }
      let row = [Card(r.id, y, color), Label(r.id, y + 14, title)]
      Step(y + gap, concat(acc.prims, row))
    })
  compute status : String = "${int_to_text(count(records))} records | next y ${int_to_text(laid.y)}"
  compute view : AppView = { status: status, choices: choices, canvas: laid.prims }
  output view : AppView
}
