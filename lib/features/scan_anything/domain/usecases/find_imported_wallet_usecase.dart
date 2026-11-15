import 'package:bb_mobile/features/import_watch_only_wallet/public/import_watch_only_facade.dart'
    show
        WatchOnlyDescriptorEntity,
        WatchOnlyDescriptorEntityExtension,
        WatchOnlyWalletEntity;
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' show Wallet;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart' show Err, Ok;

class FindImportedWalletUsecase {
  final GetWalletsUsecase _getWalletsUsecase;

  const FindImportedWalletUsecase({required this._getWalletsUsecase});

  Future<Wallet?> execute(WatchOnlyWalletEntity entity) async {
    try {
      final List<Wallet> wallets;
      switch (await _getWalletsUsecase.execute(onlyBitcoin: true)) {
        case Ok(:final value):
          wallets = value;
        case Err():
          return null;
      }
      final fingerprint = entity is WatchOnlyDescriptorEntity
          ? entity.masterFingerprint
          : '';
      for (final wallet in wallets) {
        if (wallet.network != entity.network ||
            wallet.scriptType != entity.scriptType) {
          continue;
        }
        final sameFingerprint =
            fingerprint.isNotEmpty &&
            wallet.masterFingerprint.toLowerCase() == fingerprint.toLowerCase();
        if (sameFingerprint || wallet.xpub == entity.pubkey) return wallet;
      }
      return null;
    } catch (e) {
      log.warning('Scan anything: wallet match unavailable (${e.runtimeType})');
      return null;
    }
  }
}
