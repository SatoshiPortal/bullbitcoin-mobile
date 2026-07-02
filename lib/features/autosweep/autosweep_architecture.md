# AutoSweep Architecture

AutoSweep drains enabled source wallets into the matching default wallet for the
same environment and network family.

## Boundaries

- `domain/` owns the fee policy, the sealed `AutosweepError` family, and the
  `AutosweepWalletPort` capability abstraction for default wallet lookup,
  current receive address selection, and drain transaction
  construction/signing.
- `domain/usecases/run_auto_sweep_usecase.dart` owns sweep orchestration. It is
  registered as a lazySingleton on purpose so its in-flight wallet id set can
  deduplicate sweeps across concurrent sync triggers.
- `data/autosweep_wallet_adapter.dart` is the only AutoSweep class that imports
  concrete wallet repositories. It implements the domain port and maps raw
  repository exceptions to the sealed `AutosweepError` family.
- `public/autosweep_facade.dart` is the only AutoSweep entry point for other
  features.
- `autosweep_locator.dart` wires the facade, use case, port adapter, and policy
  into the app locator.
- Broadcasting is delegated to core blockchain use cases. Labels are delegated
  through the labels facade.

## Outcome Reporting

Every sweep attempt resolves to a sealed `AutosweepResult`: `AutosweepSwept`
with the broadcast txid, `AutosweepSkipped` with a typed reason (disabled,
dust, in flight, no default wallet, self sweep, fee policy), or
`AutosweepFailed` carrying an `AutosweepError`. Consumers log failed outcomes
distinctly today; user-facing surfacing of sweep outcomes lands with the later
wallet readiness work and depends on this contract.

## Address Policy

AutoSweep sends to the default wallet receive address returned by the wallet
address repository's current-address path. For Bitcoin this is the last revealed
external address unless it has been used, in which case the wallet repository
reveals the next unused address. For Liquid it uses LWK's last-unused address.

AutoSweep must not request a fresh address on every sweep attempt, because failed
or retried sweeps should not churn receive indexes unnecessarily.
