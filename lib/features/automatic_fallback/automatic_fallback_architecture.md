# Automatic fallback

Automatic fallback owns the mobile setup and restore path for the merchant-wide Bitcoin address used when normal invoice settlement cannot complete.

## Invariants

- The authenticated server commitment is read before the client selects any address.
- First setup selects one fresh external receive address from the current default, locally signing Bitcoin mainnet wallet.
- The client proves the selected or restored address belongs to that wallet before it labels or registers it.
- One system label records a pending candidate before the remote write, allowing an ambiguous failed attempt to retry the same address.
- A successful write is accepted only after an authenticated readback returns the exact same address and valid commitment metadata.
- An existing remote commitment is never replaced when the app's default wallet changes.
- Seed restore verifies the committed address belongs to the restored wallet and recreates its local system label.
- No descriptor, seed, extended private key, private key, or signing diagnostic crosses the feature's ports, facade, logs, or Bullnym registration call.

## Flow

`AutomaticFallbackFacade -> EnsureAutomaticFallbackAddressUsecase -> AutomaticFallbackWalletPort + AutomaticFallbackServicePort -> wallet/Bullnym/labels adapters`

The Get Paid hub calls this feature through `EnsureGetPaidAutomaticFallbackUsecase` only after a wallet-owned nym exists. Setup failure leaves the other Get Paid product reads available and surfaces the dashboard's existing generic refresh error.

## Commitment point

The Bullnym registration is the durable external commitment point. Before it, address ownership and local label persistence must succeed. After it, the client never attempts rollback or address replacement; it performs an authenticated readback, and any disagreement becomes an integrity failure for supervision.

## Exclusions

This feature does not create a recovery wallet, enable AutoSweep, expose manual recovery controls, retry incident settlement from the phone, send descriptors or keys, or make phone connectivity part of server-side fallback execution.
