# entities

Business entities shared across features: the model of a domain concept and the
logic that belongs to the concept rather than to any one screen.

Empty by design. SPEC 02 establishes the layer; the first entities arrive with
the first real feature.

This file exists so the layer is present in a clean clone — git does not track
empty directories. Delete it once the layer holds real slices.

## Import rules

Enforced by the `fsd_lint` analyzer plugin (SPEC 02, steps 12 to 14):

- May import from `shared`, and nothing above it.
- May not import from `features` or `app`.
- Sibling slices may not import each other.
- Reach another slice through its `index.dart`, never deeper.
