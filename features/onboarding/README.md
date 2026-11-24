# Onboarding

`OnboardingFeature.mount` owns the onboarding routes, splash, advanced options and recovery screens. The host supplies wallet creation and recovery, language access, the logo and background images, and the navigation that follows a ready wallet.

## Dependencies

- `mnemonic_entry` supplies typed recovery input with explicit language selection; `wallet_import` supplies the read-only Bitcoin history scan. `bull_recoverbull` supplies public recovery navigation.
- `settings` supplies the machine translation warning shown after a language change.
