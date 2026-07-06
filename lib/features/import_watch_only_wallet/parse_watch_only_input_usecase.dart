import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:meta/meta.dart';

/// Parses pasted/scanned text into a [WatchOnlyWalletEntity].
///
/// This use-case is the boundary for the foreign `satoshifier` parser: it
/// catches the raw rejection, logs it, and maps it to a sanitized
/// [InvalidFormatFailure] so the cubit stays free of `try/catch`.
class ParseWatchOnlyInputUsecase {
  @useResult
  Future<Result<WatchOnlyWalletEntity, ImportWatchOnlyFailure>> execute(
    String input,
  ) async {
    try {
      final entity = await WatchOnlyWalletEntity.parse(input);
      return Ok(entity);
    } catch (e, st) {
      // Keep the raw parse reason in the logs; the UI shows a generic
      // localized message. Malformed input is an expected user-facing
      // condition, so this is a warning.
      log.warning('Failed to parse watch-only input', error: e, trace: st);
      return const Err(InvalidFormatFailure());
    }
  }
}
