import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:primitives/primitives.dart' show Outpoint;

abstract class WalletTransactionRepository {
  //Stream<WalletTransaction> get walletTransactions;
  Future<List<WalletTransaction>> getWalletTransactions({
    String? txId,
    String? walletId,
    String? toAddress,
    Environment? environment,
    bool sync = false,
  });
  Future<WalletTransaction?> getWalletTransaction(
    String txId, {
    required String walletId,
    bool sync = false,
  });

  /// The id of the wallet transaction that spends every one of [outpoints],
  /// or null, from the wallet's local state. Cheap enough to run on each sync.
  Future<String?> findTransactionSpending({
    required String walletId,
    required List<Outpoint> outpoints,
  });
}
