import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_sync_operation_exception.dart';
import 'package:transaction_sync/transaction_sync.dart';

/// Wallet-less legacy remote lookups cannot prove their inputs are unrelated to CBF. Refuse before giving a parent txid or signed payload to a server.
final class CbfPrivacyGuard {
  final WalletMetadataDatasource metadata;
  final WalletSourceOperationCoordinator? coordinator;

  const CbfPrivacyGuard(this.metadata, [this.coordinator]);

  Future<T> runElectrum<T>(
    Iterable<String?> walletIds,
    Future<T> Function() operation,
  ) async {
    final ids = walletIds.whereType<String>().toSet().toList()..sort();
    Future<T> acquire(int index) async {
      if (index == ids.length) return operation();
      final id = ids[index];
      final wallet = await metadata.fetch(id);
      if (wallet == null) {
        throw const BitcoinSyncOperationException(DeletedWalletFailure());
      }
      final lock = coordinator;
      Future<T> admitted() async {
        await requireWalletElectrum(id);
        return acquire(index + 1);
      }

      if (lock == null) return admitted();
      return lock.runExclusive(
        WalletSourceKey(
          id,
          wallet.isBitcoin ? 'bitcoin' : 'liquid',
          wallet.isTestnet ? 'testnet' : 'mainnet',
        ),
        (_) => admitted(),
        timeout: null,
      );
    }

    return acquire(0);
  }

  Future<T> runUnattributedElectrum<T>(Future<T> Function() operation) async {
    final wallets = await metadata.fetchAll();
    return runElectrum(
      wallets.where((wallet) => wallet.isBitcoin).map((wallet) => wallet.id),
      () async {
        await requireUnattributedElectrum();
        return operation();
      },
    );
  }

  Future<void> requireWalletElectrum(String? walletId) async {
    if (walletId == null) return;
    final wallet = await metadata.fetch(walletId);
    if (wallet?.isBitcoin == true &&
        wallet?.bitcoinSyncSource == BitcoinSyncSource.compactBlockFilters) {
      throw const BitcoinSyncOperationException(
        CbfRemoteLookupForbiddenFailure(),
      );
    }
  }

  Future<void> requireUnattributedElectrum() async {
    final wallets = await metadata.fetchAll();
    if (wallets.any(
      (wallet) =>
          wallet.isBitcoin &&
          wallet.bitcoinSyncSource == BitcoinSyncSource.compactBlockFilters,
    )) {
      throw const BitcoinSyncOperationException(
        CbfRemoteLookupForbiddenFailure(),
      );
    }
  }
}
