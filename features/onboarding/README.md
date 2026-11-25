# Onboarding

`OnboardingFeature.mount` owns the onboarding routes, splash, advanced options and recovery screens. It creates or restores the default wallets through `provisioning` and records the verified physical backup in the RecoverBull backup facts of the restored network. The host supplies those capabilities, language access, the logo and background images, and the navigation that follows a ready wallet.

## Dependencies

- `mnemonic_entry` supplies typed recovery input with explicit language selection; `wallet_import` supplies the read-only Bitcoin history scan. `bull_recoverbull` supplies public recovery navigation and the wallet backup facts. `provisioning` creates or restores the default wallet pair.
- `settings` supplies the machine translation warning shown after a language change.
