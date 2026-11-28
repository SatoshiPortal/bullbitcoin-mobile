# Ark feature

## Exit notifications

The Android Regtest Ark worker may notify when a fresh, complete exit observation shows every member of a journalled exit group as claimable. A separate durable ledger keeps one platform ID per account and group; it never replays a show from a stored observation. Claim admission records and attempts cancellation while the Ark writer is held, and a later observation retries an interrupted cancellation. A fresh observation that no longer shows the whole group claimable withdraws its alert without announcing the group again. A refused OS permission settles the alert without a backlog; an undetermined or unavailable gateway can retry only after another fresh observation.

The foreground creates the ledger and the headless worker opens only an existing ledger. A missing initialized ledger, a damaged marker or invalid stored state is refused rather than silently resetting deduplication. SQLite and Android effects are not atomic: a crash after claim admission can leave an alert visible until a later observation, and a crash after showing can replay the same ID without an intervening cancellation. A notification the user has dismissed can still be shown again after an interruption. These alerts do not prove that a claim has been signed, broadcast or confirmed.

## Dependencies

- `sync` supplies funding, wallet display data and the native runtime used by Ark journeys.
- `address_view` renders the admitted funding address, and `spend` prepares, signs and broadcasts reserve top-ups from the account's bound wallet.
