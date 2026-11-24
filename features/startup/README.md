# App startup

`StartupFeature.mount` composes the launch sequence: access gating, default wallet checks and repair, required Tor initialization and swap startup, followed by the recovery screens shown when a default secret is missing.

## Dependencies

- `bull_ui` supplies the app theme. The root app supplies the machine translation warning through `onMachineTranslationSelected`. Bootstrap passes the Exchange platform availability decision into the separately mounted Wizard.
- `mnemonic_entry` supplies the typed recovery input with explicit language selection.
- `bull_recoverbull` supplies the public mainnet backup lookup used to decide whether Tor is required during startup.
- `provisioning` repairs missing default wallets, and `secrets` exposes the inventory and recovery wallets.
