# Mempool

`Mempool` owns Bitcoin and Liquid explorer links, configured servers and connectivity validation. It owns `databases/mempool.sqlite` (encrypted schema 1) and opens only under a runtime admission from `legacy_storage`.

```dart
final opened = await Mempool.open(file: file, admission: admission, tor: getTor, torHttp: http);
if (opened case Err(:final failure)) return;
final mempool = (opened as Ok<Mempool, MempoolFailure>).value;
final transaction = await mempool.links.transaction(txid, network: BitcoinNetwork.testnet);
final addressLink = await mempool.links.address(address, network: LiquidNetwork.mainnet);
final servers = await mempool.servers.fetch(network: BitcoinNetwork.testnet);
final candidate = MempoolServer.tryCreateCustom(url: host, network: BitcoinNetwork.testnet);
if (candidate case Ok(:final value)) {
  final saved = await mempool.servers.store(value);
}
final removed = await mempool.servers.trash(network: BitcoinNetwork.testnet);
final feesBase = await mempool.servers.activeBase(network: BitcoinNetwork.testnet);
```

Operations return `Result` values with a `MempoolFailure` on failure. Link results contain a `Uri`. Use `fragment` for a Bitcoin transaction's output details and `links.unblindedTransaction` with the wallet's explorer-relative Liquid path. Signet and regtest return an unsupported-network failure. The app routes Bitcoin regtest fees through Electrum.

The active server is the custom server when configured. Only a successful lookup with no custom server falls back to the default. The active Bitcoin fee base preserves the selected server's scheme, port and base path. The actual fee request is owned by the app's Fees feature.

`servers.store` validates a custom endpoint before saving it. `servers.validate` probes a server returned by `servers.fetch` and uses the configured Tor session for onion endpoints. `package:mempool/migration.dart` publishes an inert import participant. The foreground coordinator prepares it under exclusivity, copies and verifies every historical column in one transaction with `split-v1/mempool`, then closes preparation handles before admitting runtime reads. New installations atomically seed and record `fresh-v1/mempool`; schema version alone is not readiness. Repeated imports never overwrite later destination edits. `storage.dart` remains the declarations required by the immutable historical migration chain, not the runtime store supplied to consumers.

The production opener constructs its keyed native connection in an owner-controlled Drift isolate. Secrets retains the key material; Mempool receives only the executor. Closure includes server shutdown and remains registered with the admission until confirmed. A locked keystore is deferred; missing or incorrect keys never cause automatic regeneration or reset. Generate the v1 snapshot with `make mempool-drift-migrations`.
