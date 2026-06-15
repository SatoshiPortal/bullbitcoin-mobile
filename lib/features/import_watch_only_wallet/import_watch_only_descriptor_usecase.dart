import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_error.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';

class ImportWatchOnlyDescriptorUsecase {
  final WalletRepository _wallet;

  ImportWatchOnlyDescriptorUsecase({required WalletRepository walletRepository})
    : _wallet = walletRepository;

  Future<Wallet> execute({
    required WatchOnlyDescriptorEntity watchOnlyDescriptor,
  }) async {
    try {
      final wallet = await _wallet.importDescriptor(
        watchOnlyDescriptor: watchOnlyDescriptor,
      );

      return wallet;
    } on ImportWatchOnlyError {
      rethrow;
    } catch (e, st) {
      // Keep the raw descriptor/BDK rejection reason in the logs; the UI shows
      // a generic localized message. A rejected descriptor is an expected
      // user-facing condition (malformed input), so this is a warning.
      log.warning('Failed to import watch-only descriptor', error: e, trace: st);
      throw const ImportFailedError();
    }
  }
}
