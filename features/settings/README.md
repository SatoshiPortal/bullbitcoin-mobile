# Settings

`SettingsFeature.mount` owns the settings hub, its search and the settings routes it mounts. The member also owns support entry points and the wallet settings detail, discovery and deletion flow.

## Dependencies

- `bull_exchange` supplies typed support chat navigation and the chat UI.
- `secrets` supplies admitted wallet metadata and exclusive seed-reference cleanup. `signers` supplies device metadata and `sync` owns native account deletion.
- `swaps` supplies pending transfers and orders. A failed read is not proof that deleting a wallet is safe.
- `bull_ark` supplies the published Settings UI and debug notification setup.
- `wallet_import` supplies typed import navigation, `send` supplies signed-transaction navigation, and `receive` supplies the Payjoin disclosure widget. The app's route composition is described in [ARCHITECTURE.md](../../ARCHITECTURE.md).
