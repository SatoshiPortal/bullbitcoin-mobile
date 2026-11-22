import 'package:electrum/src/domain/value_objects/electrum_connection.dart';
import 'package:sync/sync.dart' show BitcoinTx;

/// Fetches a parsed Bitcoin transaction from a given Electrum server.
///
/// Server selection and fallback are the caller's responsibility — this repo
/// is a thin abstraction over a single server fetch (with local caching), and
/// takes the already-resolved [ElectrumConnection] so the transport (scheme,
/// certificate validation, timeout) matches what the sync path uses.
/// Returns the parsed [BitcoinTx]; cross-module domain mapping is left to
/// callers so the electrum module's domain does not depend on another
/// module's domain entities.
abstract interface class ElectrumTransactionRepository {
  Future<BitcoinTx> fetch({
    required ElectrumConnection connection,
    required String txid,
  });
}
