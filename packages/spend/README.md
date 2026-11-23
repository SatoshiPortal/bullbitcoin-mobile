# Spend

`Spend.open` composes wallet-bound Bitcoin and Liquid preparation, review, software signing and broadcast. The inventory supplies the current public wallet identity and optional signer reference through `package:spend/setup.dart`. Sync owns native stores, transaction admission, freezes, the connection policy and broadcast receipts. Secrets owns the key operation; Ark admits ordinary Bitcoin signing before it can read the key.

Keep the prepared value from review through signing. For hardware and air-gap signing, send its PSBT through the feature's Signers navigation, then verify the returned PSBT or raw transaction against the same prepared value. Imported Bitcoin broadcast is separate: it requires a captured network and checks the global freezes, without claiming a wallet generation.

A receipt with `guarded: true, durable: false` is successful; Sync is still guarding the inputs and observing the broadcast. An unknown broadcast outcome is never a rejection or permission to replace the payment. A partial Liquid consolidation reports the accepted transaction IDs and the cause of the interruption.

Use `SpendCatalog.fromInventory` with the foreground `WalletInventory`. This package does not compose the legacy app wallet catalogue. Payjoin handoff is unavailable until the protocol and Sync can atomically reserve a prepared spend for a durable sender session. `package:spend/testing.dart` provides a strict fake and test-only values with no broadcast identity.
