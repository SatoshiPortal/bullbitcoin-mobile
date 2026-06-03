# AutoSweep Architecture

AutoSweep drains enabled source wallets into the matching default wallet for the
same environment and network family.

## Boundaries

- `application/` owns sweep orchestration and fee policy.
- `autosweep_locator.dart` wires the use case and policy into the app locator.
- Wallet selection, address lookup, transaction construction, broadcasting, and
  labels are delegated to existing core services and the labels facade.

## Address Policy

AutoSweep sends to the default wallet receive address returned by the wallet
address repository's current-address path. For Bitcoin this is the last revealed
external address unless it has been used, in which case the wallet repository
reveals the next unused address. For Liquid it uses LWK's last-unused address.

AutoSweep must not request a fresh address on every sweep attempt, because failed
or retried sweeps should not churn receive indexes unnecessarily.
