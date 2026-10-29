import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/bitcoin_sync_routing.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';
import '../domain/repositories/cbf_recovery_repository.dart';
import '../domain/transaction_failure.dart';

final class CbfRecoveryRepositoryImpl implements CbfRecoveryRepository {
  final WalletMetadataDatasource _wallets;
  final BitcoinSyncRouting _routing;

  const CbfRecoveryRepositoryImpl(this._wallets, this._routing);

  @override
  Future<Result<void, TransactionFailure>> retry(
    String walletId,
    String txid,
  ) => _recover(walletId, txid, cancel: false);

  @override
  Future<Result<void, TransactionFailure>> cancel(
    String walletId,
    String txid,
  ) => _recover(walletId, txid, cancel: true);

  Future<Result<void, TransactionFailure>> _recover(
    String walletId,
    String txid, {
    required bool cancel,
  }) async {
    try {
      final wallet = await _wallets.fetch(walletId);
      if (wallet == null ||
          !wallet.isBitcoin ||
          wallet.bitcoinSyncSource != BitcoinSyncSource.compactBlockFilters) {
        return const Err(TransactionCbfUnavailableFailure());
      }
      final deadline = DateTime.now().toUtc().add(const Duration(seconds: 30));
      final registration = await _routing.registration(
        wallet,
        verifyTor: !cancel,
        deadline: deadline,
      );
      final result = cancel
          ? await _routing.facade.cancelCbfTransaction(registration, txid)
          : await _routing.facade.retryCbfTransaction(registration, txid);
      return switch (result) {
        Ok() => const Ok(null),
        Err(:final failure) => Err(switch (failure) {
          CbfTorUnavailableFailure() => const TransactionCbfTorFailure(),
          CbfTransactionNotRecoverableFailure() =>
            const TransactionCbfUnavailableFailure(),
          _ => const TransactionCbfRecoveryFailure(),
        }),
      };
    } on Exception {
      return const Err(TransactionCbfRecoveryFailure());
    }
  }
}
