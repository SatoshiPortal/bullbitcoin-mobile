import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_error.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';

class ImportWatchOnlyXpubUsecase {
  final WalletRepository _wallet;

  ImportWatchOnlyXpubUsecase({required WalletRepository walletRepository})
    : _wallet = walletRepository;

  Future<Wallet> execute({required WatchOnlyXpubEntity watchOnlyXpub}) async {
    try {
      final wallet = await _wallet.importWatchOnlyXpub(
        xpub: watchOnlyXpub.pubkey,
        network: watchOnlyXpub.network,
        scriptType: watchOnlyXpub.scriptType,
        label: watchOnlyXpub.label,
      );

      return wallet;
    } on ImportWatchOnlyError {
      rethrow;
    } catch (e, st) {
      // Keep the raw xpub/BDK rejection reason in the logs; the UI shows a
      // generic localized message. A rejected xpub is an expected user-facing
      // condition (malformed input), so this is a warning.
      log.warning('Failed to import watch-only xpub', error: e, trace: st);
      throw const ImportFailedError();
    }
  }
}
