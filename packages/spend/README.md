# Spend

`Spend.open` composes wallet-bound Bitcoin and Liquid preparation, review, software signing and broadcast. The inventory supplies the current public wallet identity and optional signer reference through `package:spend/setup.dart`. Sync owns native stores, transaction admission, freezes, the connection policy and broadcast receipts. Secrets owns the key operation; Ark admits ordinary Bitcoin signing before it can read the key.

Unselected Bitcoin preflight and Bitcoin/Liquid signing read Sync's fresh set of frozen outpoints, regardless of freeze origin. An unreadable policy refuses before checking protocol reservations; an empty set is a successful read, not a substitute for that reservation check.

Keep the prepared value from review through signing. For hardware and air-gap signing, send its PSBT through the feature's Signers navigation, then verify the returned PSBT or raw transaction against the same prepared value. Imported Bitcoin broadcast is separate: it requires a captured network and checks the global freezes, without claiming a wallet generation.

A receipt with `guarded: true, durable: false` is successful; Sync is still guarding the inputs and observing the broadcast. An unknown broadcast outcome is never a rejection or permission to replace the payment. A partial Liquid consolidation reports the accepted transaction IDs and the cause of the interruption.

If a swap already persisted its signed payin, recovery submits those same bytes only. It verifies the recorded source wallet, concrete network, pinned destination and amount before re-entering the current Sync writer. It never asks Spend to build or sign another transaction.

Use `SpendCatalog.fromInventory` with the foreground `WalletInventory`. This package does not compose the legacy app wallet catalogue. Payjoin handoff checks the signed original against the preparation, then asks Sync to admit the exact generation and inputs. Its persistence callback must write the Payjoin session only; success requires the owner's reservation to be observable before Sync releases admission. `package:spend/testing.dart` provides a strict fake and test-only values with no broadcast identity.
