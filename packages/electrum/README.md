# Electrum

`Electrum.open` asynchronously returns a typed Result after opening the prepared encrypted schema-1 owner database. The capability owns its database worker; the runtime admission retains the lease until native closure is acknowledged. The Result-returning Preferences callback and the Tor callback stay lazy and borrowed. Foreground storage preparation and adapters for sync and native operations live in `package:electrum/setup.dart`.

```dart
final opened = await Electrum.open(
  file: file,
  admission: admission,
  readPreferences: preferences.readConnectionPreferences,
  tor: getTor,
);
if (opened case Err(:final failure)) return Err(failure);
final electrum = (opened as Ok<Electrum, ElectrumFailure>).value;
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

`servers.check` uses the active priority list and only considers defaults if there are no custom endpoints. Subscribe to `servers.watchChecks(network: ...)` for one settings refresh. It emits the catalog with unknown statuses and then an updated snapshot for each completed probe. In-flight probes release their Tor routes after cancellation. Storage identifiers are the network and stored endpoint URL. `servers.trash` removes a custom endpoint by that identifier. `servers.prioritize` accepts the complete list of custom URLs in the desired order. `servers.options.fetch` and `servers.options.store` read or write options for one network.

Operations return typed `ElectrumFailure` values. Transaction decoding belongs to `sync`. The schema-1 owner retains the historical table names and raw row formats. `ElectrumImport` copies servers, settings and the complete transaction cache under exclusive admission, verifies exact rows and commits its sole receipt atomically. The historical schema-16 composer and published migration chain remain available for other owners; this slice never deletes legacy data. Background opens require existing schema and readiness and never migrate or seed. Test-only injected construction and cache inspection are published exclusively through `testing.dart`.
