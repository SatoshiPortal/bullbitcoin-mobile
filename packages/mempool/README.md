# Mempool

`Mempool` owns Bitcoin and Liquid explorer links, configured servers and connectivity validation. Compose it once with the app's Drift database and Tor services.

```dart
final mempool = Mempool.open(database: database, tor: getTor, torHttp: http);
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

`servers.store` validates a custom endpoint before saving it. `servers.validate` probes a server returned by `servers.fetch` and uses the configured Tor session for onion endpoints. Import `package:mempool/storage.dart` when composing or seeding the member's Drift tables.
