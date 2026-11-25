# Wallet Import

`ImportFeature.mount` contributes the import hub, mnemonic and watch-only confirmation, scanning and hardware instructions. The host supplies `WalletProvisioning` and the Secrets custody admission port.

## Dependencies

- `scanning` provides QR acquisition for watch-only descriptors and NFC for Coldcard. `signers` provides hardware wallet properties and `mnemonic_entry` supplies the typed recovery phrase.
- `secrets` supplies the authorized inventory for duplicate checks on the captured network and admits mnemonic imports. Wallet Import validates watch-only inputs before calling `provisioning` to register and create the account.
