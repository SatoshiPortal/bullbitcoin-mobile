# POS Settlement Descriptor

The v1 controller authorizes each terminal with the selected Liquid wallet's
existing external CT descriptor. This keeps the POC recoverable by the wallet's
normal Liquid scanner and avoids inventing a descriptor branch that LWK may not
track.

Each terminal still receives a unique `terminal_branch` index in the encrypted
authorization. The current cashier can treat that as metadata; a future SDK
upgrade can use the same index to derive terminal-scoped subdescriptors once
LWK support is confirmed end-to-end.

Private keys are never sent to a terminal. The descriptor is sensitive because
it exposes future receive addresses, so the controller stores the descriptor
copy in secure storage and only keeps a reference in Drift.

The privacy-bucket secret used for sale event discovery is handled the same
way: Bull Wallet stores the secret in secure storage and persists only the
opaque terminal id, generation number, effective day, and secure-storage
reference in Drift. Relay queries are made with daily `x` bucket tags, not with
the merchant POS reference or terminal public key.
