# Provisioning

`WalletProvisioning.open` creates default, mnemonic and watch-only accounts. Provisioning coordinates durable catalog registration with native account creation and compensates for a refused native creation. `DefaultWalletProvisioning` creates or resumes the default Bitcoin and Liquid pair.

## Dependencies

- `secrets` owns the admitted inventory, public derivation and account property preparation.
- `sync` owns native account creation, write admission and repair.
- `preferences` supplies the active environment for defaults; `satoshifier` validates and normalizes imported public extended keys.
- `legacy_storage` is used only by tests to exercise registration against a real inventory fixture.
