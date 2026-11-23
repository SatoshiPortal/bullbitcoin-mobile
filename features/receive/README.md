# Receive requests

## Dependencies

- `address_view` supplies indexed addresses. Receive owns request admission, pricing, address notes and the choice between a transfer address and the next unused address.
- `secrets` supplies the authorized wallet inventory, `sync` supplies exact-network balances, and `signers` supplies hardware associations. `transactions` and `swaps` supply incoming transaction and order observations. The shell binds the post-payment wallet sync.
