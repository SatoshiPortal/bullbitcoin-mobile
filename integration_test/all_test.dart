// Single-entrypoint aggregator: builds and launches the Linux app once, runs
// Bull.init() once, then delegates to every integration test file's main with
// isInitialized: true (the parameter each file exposes for exactly this).
//
// Why: on the Linux desktop device `flutter test` can launch the app only once
// per invocation, so `flutter test integration_test/` (whole dir) fails every
// file but the first. Running this one file instead collapses N builds + N
// launches into one. The trade-off is that all tests share a single process
// (and the on-disk SQLite db), so state can bleed between files.
//
// payjoin_test is intentionally absent — it's commented out (needs funded
// testnet wallets + TEST_*_MNEMONIC) and exposes no main().
import 'package:bb_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bip85_derivation_test.dart' as bip85_derivation;
import 'exchange_rate_test.dart' as exchange_rate;
import 'recoverbull_test.dart' as recoverbull;
import 'sqlite_transactions_test.dart' as sqlite_transactions;
import 'sqlite_wallet_metadata_test.dart' as sqlite_wallet_metadata;

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await Bull.init();

  await exchange_rate.main(isInitialized: true);
  await sqlite_transactions.main(isInitialized: true);
  await sqlite_wallet_metadata.main(isInitialized: true);
  await bip85_derivation.main(isInitialized: true);
  await recoverbull.main(isInitialized: true);
}
