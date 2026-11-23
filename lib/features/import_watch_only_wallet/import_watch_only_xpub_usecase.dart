import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
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
      final validated = watchOnlyXpub.captureNetwork(watchOnlyXpub.network);
      if (validated is! WatchOnlyXpubEntity) {
        return const Err(InvalidFormatFailure());
      }
      final wallet = await _wallet.importWatchOnlyXpub(
        xpub: validated.pubkey,
        network: validated.network,
        scriptType: validated.scriptType,
        label: validated.label,
      );
      return Ok(wallet);
    } on WatchOnlyNetworkMismatchException {
      return const Err(NetworkMismatchFailure());
    } on FormatException {
      return const Err(InvalidFormatFailure());
    } catch (e) {
      if (e is Error) rethrow;
      // Do not log imported material or a foreign exception containing it.
      log.warning('Failed to import watch-only xpub');
      return switch (e) {
        WalletAlreadyExistsException() => const Err(
          WalletAlreadyExistsFailure(),
        ),
        _ => const Err(ImportFailedFailure()),
      };
    }
  }
}
