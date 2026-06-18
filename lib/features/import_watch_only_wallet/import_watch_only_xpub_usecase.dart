import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:meta/meta.dart';

class ImportWatchOnlyXpubUsecase {
  final WalletRepository _wallet;

  ImportWatchOnlyXpubUsecase({required WalletRepository walletRepository})
    : _wallet = walletRepository;

  /// Wraps the still-throwing core [WalletRepository]; this use-case is the
  /// boundary that catches the raw rejection, logs it, and maps it to a
  /// sanitized [ImportWatchOnlyFailure].
  @useResult
  Future<Result<Wallet, ImportWatchOnlyFailure>> execute({
    required WatchOnlyXpubEntity watchOnlyXpub,
  }) async {
    try {
      final wallet = await _wallet.importWatchOnlyXpub(
        xpub: watchOnlyXpub.pubkey,
        network: watchOnlyXpub.network,
        scriptType: watchOnlyXpub.scriptType,
        label: watchOnlyXpub.label,
      );
      return Ok(wallet);
    } catch (e, st) {
      // Keep the raw xpub/BDK rejection reason in the logs; the UI shows a
      // generic localized message. A rejected xpub is an expected user-facing
      // condition (malformed input), so this is a warning.
      log.warning('Failed to import watch-only xpub', error: e, trace: st);
      return const Err(ImportFailedFailure());
    }
  }
}
