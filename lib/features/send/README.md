# Send

## Dependencies

- `satoshifier` parses payment requests; `coins` supplies the public coin management route. `bull_ark` supplies Ark's public capability.
- The wallet supplies public spend admission and revisions. The transaction composition handles the reviewed Payjoin original through Spend.
- The `send` workspace feature handles signed-transaction handoff and consolidation status. `address_view` supplies destination input and review widgets.
