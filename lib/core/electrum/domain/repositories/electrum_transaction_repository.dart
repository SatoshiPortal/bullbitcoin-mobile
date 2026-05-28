import 'package:bb_mobile/core/utils/bitcoin_tx.dart';

/// Fetches a parsed Bitcoin transaction from a given Electrum server.
///
/// Server selection and fallback are the caller's responsibility — this repo
/// is a thin abstraction over a single server fetch (with local caching).
/// Returns the parsed [BitcoinTx]; cross-module domain mapping is left to
/// callers so the electrum module's domain does not depend on another
/// module's domain entities.
abstract class ElectrumTransactionRepository {
  Future<BitcoinTx> fetch({required String serverUrl, required String txid});
}
