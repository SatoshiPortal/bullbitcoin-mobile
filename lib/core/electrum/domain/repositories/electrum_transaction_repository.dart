import 'package:bb_mobile/core/transactions/domain/entity/bitcoin_transaction.dart';

/// Fetches a parsed Bitcoin transaction from a given Electrum server and
/// returns the [BitcoinTransaction] domain entity.
///
/// Server selection and fallback are the caller's responsibility — this repo
/// is a thin abstraction over a single server fetch (with local caching).
abstract class ElectrumTransactionRepository {
  Future<BitcoinTransaction> fetch({
    required String serverUrl,
    required String txid,
    required bool isTestnet,
  });
}
