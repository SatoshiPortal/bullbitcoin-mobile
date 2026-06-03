# AutoSweep Architecture

AutoSweep drains enabled source wallets into the matching default wallet for the
same environment and network family.

## Boundaries

- `application/` owns sweep orchestration and fee policy.
- `public/autosweep_facade.dart` is the only AutoSweep entry point for other
  features.
- `application/ports/autosweep_wallet_port.dart` is the application boundary for
  default wallet lookup, current receive address selection, and drain
  transaction construction/signing.
- `frameworks/autosweep_wallet_adapter.dart` is the only AutoSweep class that
  imports concrete wallet repositories.
- `autosweep_locator.dart` wires the facade, use case, port adapter, and policy
  into the app locator.
- Broadcasting is delegated to core blockchain use cases. Labels are delegated
  through the labels facade.

## Address Policy

AutoSweep sends to the default wallet receive address returned by the wallet
address repository's current-address path. For Bitcoin this is the last revealed
external address unless it has been used, in which case the wallet repository
reveals the next unused address. For Liquid it uses LWK's last-unused address.

AutoSweep must not request a fresh address on every sweep attempt, because failed
or retried sweeps should not churn receive indexes unnecessarily.
