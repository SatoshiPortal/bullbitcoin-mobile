# Address View

## Dependencies

- `secrets` supplies the typed wallet inventory; `sync` reads address usage and issues addresses for the selected wallet. `labels` enriches the indexed addresses.
- `scanning` supplies destination scanning, `bull_payjoin` supplies the regtest Payjoin URI, and `silent` supplies Silent Payments for label scan and clear flows.
