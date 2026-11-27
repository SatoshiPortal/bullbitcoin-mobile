# App startup

`StartupFeature.mount` composes the launch sequence: access gating, default wallet checks and repair, required Tor initialization and swap startup, followed by the recovery screens shown when a default secret is missing.

`ForegroundWalletStartup` admits local balance work only after the accepted unlock continuation (or explicit no-PIN launch) and a successful native initialization. A failed initialization does not block the shell and cannot be retried by the balance scheduler. `ForegroundBalanceStartup` captures the current catalogue and environment epoch at each admission, coalesces work per exact key, and drains on disposal without owning or closing Sync. Its work is not awaited by navigation, and it does not drive Overview.

## Dependencies

- `bull_ui` supplies the app theme. The root app supplies the machine translation warning through `onMachineTranslationSelected`. Bootstrap passes the Exchange platform availability decision into the separately mounted Wizard.
- `mnemonic_entry` supplies the typed recovery input with explicit language selection.
- `bull_recoverbull` supplies the public mainnet backup lookup used to decide whether Tor is required during startup.
- `provisioning` repairs missing default wallets, and `secrets` exposes the inventory and recovery wallets.
- `sync` supplies read-only retained balance demand and native revision events on the existing foreground owner; Startup does not provision or refresh native wallets.
