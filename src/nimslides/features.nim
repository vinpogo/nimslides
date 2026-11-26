## Imports every markdown feature: each `.nim` file in `features/`, found at
## compile time. Features register themselves when imported, so there is no
## list to edit; see docs/architecture.md.

{.used.}
{.warning[UnusedImport]: off.}
  # features are imported for their registrations only; this covers the
  # imports in this module, not unused imports inside the features

import ./core/discover

importAll("features")
