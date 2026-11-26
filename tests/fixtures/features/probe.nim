## Test fixture, not a feature: proves that `importAll` finds and imports a
## feature-style module that registers itself. Used by test_discover.nim.

import nimslides/core

registerInline(
  InlineRule(
    name: "probe",
    triggers: {'@'},
    parse: proc(p: InlineParser): InlineNode =
      inc p.pos
      Text(text: "<probe>"),
  )
)
