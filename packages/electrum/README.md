# Electrum

`Electrum.open` builds the capability around the application's existing Drift database, a current network reader, a preferences reader and a lazy Tor service. The caller owns those resources. Opening is synchronous. Foreground storage preparation and the adapters for sync and native operations live in `package:electrum/setup.dart`.

```dart
final electrum = Electrum.open(
  database: database,
  readNetwork: readNetwork,
  readPreferences: readPreferences,
  tor: getTor,
);
final servers = await electrum.servers.fetch(network: network);
final status = await electrum.servers.check(network: network);
final added = await electrum.servers.store(
  'electrum.example:50002',
  network: network,
  priority: 0,
  enableSsl: true,
);
final transaction = await electrum.transactions.fetch(txid, network: bitcoinNetwork);
```

`servers.check` uses the active priority list and only considers defaults if there are no custom endpoints. `servers.checkEndpoint` probes a single endpoint. Subscribe to `servers.watchChecks(network: ...)` for one settings refresh. It emits the catalog with unknown statuses and then an updated snapshot for each completed probe. In-flight probes release their Tor routes after cancellation. Storage identifiers are the network and stored endpoint URL. `servers.trash` removes a custom endpoint by that identifier. `servers.prioritize` accepts the complete list of custom URLs in the desired order. `servers.options.fetch` and `servers.options.store` read or write options for one network.

Operations return typed `ElectrumFailure` values. Transaction decoding belongs to `sync`. Drift table names, row formats and schema 16 are shared with the existing app database.
