# Signers

Hardware account reading, signing and address verification for Ledger and BitBox, plus URQR and unsigned PSBT presentation. This feature owns no wallet, settings or navigation destination outside its signer flow.

Call `SignersFeature.mount(services: getIt, writeNfc: writeNfc)` from `package:signers/routes.dart` once during foreground composition and add the returned feature's `routes` to the root router. Install `SignersLocalizations.delegate` alongside the app localization delegates and Bull UI theme extensions. The feature owns route parameters, screen builders and localized route errors. Callers use `SignersNavigation` and `SignerDevice` from `package:signers/signers.dart`.

Callers use `SignersNavigation.importLedger` / `importBitBox` to receive a `SignerAccount?`, `signLedger` / `signBitBox` to receive a signed PSBT, `verifyLedger` / `verifyBitBox` to request verification, and `showPsbt` to receive a `PsbtHandoffResult?`. The required network comes from the captured wallet or import request. Mainnet and testnet are supported; signet and regtest are refused before discovery and at the device use-case boundary. Back navigation returns no import/signing/handoff result.

Import owns descriptor construction and confirmation after receiving the public account. PSBT presentation returns only `readyToReadSignedTransaction`; the caller retains the original wallet and unsigned PSBT for the next verification step. The shell supplies the NFC writer callback and must invoke its success callback only after a confirmed write.

The module also publishes URQR decoding for scanner consumers. BBQR encoding lives here; legacy BBQR transaction decoding stays in the shell until `BitcoinTx` moves to `sync`.

Run code generation and translations through the root `make build-runner` and `make translations` targets. Run the feature tests from this directory with `fvm flutter test --concurrency 2`. No hardware is required for the unit and widget suites; actual USB/BLE device interaction requires separate device validation.
