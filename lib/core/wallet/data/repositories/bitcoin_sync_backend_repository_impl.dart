import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bitcoin_sync_backend_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';

/// [BitcoinSyncBackendRepository] backed by [WalletMetadataDatasource].
///
/// This is the only repository presentation code should reach through to
/// read or change a Bitcoin wallet's sync backend — the datasource itself is
/// never exposed past this boundary.
class BitcoinSyncBackendRepositoryImpl implements BitcoinSyncBackendRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;

  BitcoinSyncBackendRepositoryImpl({required this._walletMetadataDatasource});

  @override
  Future<Result<BitcoinSyncBackend, WalletSyncFailure>> get({
    required String walletId,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      return const Err(WalletSyncWalletNotFoundFailure());
    }
    if (!metadata.isBitcoin) {
      return const Err(WalletSyncNotBitcoinWalletFailure());
    }
    return Ok(metadata.bitcoinSyncBackend);
  }

  @override
  Future<Result<void, WalletSyncFailure>> set({
    required String walletId,
    required BitcoinSyncBackend backend,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      return const Err(WalletSyncWalletNotFoundFailure());
    }
    if (!metadata.isBitcoin) {
      return const Err(WalletSyncNotBitcoinWalletFailure());
    }
    await _walletMetadataDatasource.store(
      metadata.copyWith(bitcoinSyncBackend: backend),
    );
    return const Ok(null);
  }
}
