# Wallet Import

`ImportFeature.mount` contributes the import hub, mnemonic and watch-only confirmation, scanning and hardware instructions. The foreground wallet owner supplies provisioning through host bindings.

## Dependencies

- `scanning` provides QR acquisition for watch-only descriptors and NFC for Coldcard. `signers` provides hardware wallet properties and `mnemonic_entry` supplies the typed recovery phrase.
- `secrets` supplies the authorized inventory for duplicate checks on the captured network. Wallet Import validates a watch-only descriptor before asking the host to provision it.
