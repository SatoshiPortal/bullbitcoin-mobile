import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/cbf_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/unconfirmed_bitcoin_transaction_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';

/// [UnconfirmedBitcoinTransactionRepository] backed by
/// [WalletMetadataDatasource] (to route by the wallet's persisted
/// [BitcoinSyncBackend]), [CbfWalletDatasource] (the fast path, applied
/// directly to an active CBF session's in-memory wallet), and
/// [BdkWalletDatasource] (the fallback path when no CBF session is active
/// for the wallet).
class UnconfirmedBitcoinTransactionRepositoryImpl
    implements UnconfirmedBitcoinTransactionRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final CbfWalletDatasource _cbfWalletDatasource;
  final BdkWalletDatasource _bdkWalletDatasource;

  UnconfirmedBitcoinTransactionRepositoryImpl({
    required this._walletMetadataDatasource,
    required this._cbfWalletDatasource,
    required this._bdkWalletDatasource,
  });

  @override
  Future<Result<void, WalletSyncFailure>> record({
    required String walletId,
    required String transaction,
    required bool isPsbt,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      return const Err(WalletSyncWalletNotFoundFailure());
    }

    if (!metadata.isBitcoin) {
      // Liquid wallets have no BDK/CBF equivalent to nudge here.
      return const Ok(null);
    }

    if (metadata.bitcoinSyncBackend != BitcoinSyncBackend.compactBlockFilters) {
      // Electrum wallets already learn about their own broadcast the next
      // time they sync over the Electrum protocol; see the class doc on
      // UnconfirmedBitcoinTransactionRepository for why only CBF needs
      // this local nudge.
      return const Ok(null);
    }

    try {
      // Fast path first: if a CBF session for this wallet is already
      // running, apply directly to its in-memory wallet — see
      // CbfWalletDatasource.applyUnconfirmedTransactionIfActive's doc for
      // why this must be tried before the BdkWalletDatasource fallback,
      // which would otherwise be serialized behind that same session's
      // whole-scan lock.
      final appliedToActiveSession = await _cbfWalletDatasource
          .applyUnconfirmedTransactionIfActive(
            metadata: metadata,
            transaction: transaction,
            isPsbt: isPsbt,
          );

      if (!appliedToActiveSession) {
        final walletModel = WalletModel.fromMetadata(metadata);
        await _bdkWalletDatasource.applyUnconfirmedTransaction(
          wallet: walletModel,
          transaction: transaction,
          isPsbt: isPsbt,
          lastSeen: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
      }
      return const Ok(null);
    } catch (e) {
      // Never log the raw transaction, txid, wallet id, or descriptor here
      // — only a non-sensitive classification of what went wrong.
      return Err(WalletSyncCbfFailure('${e.runtimeType}'));
    }
  }
}
