import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
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
    String input, {
    required NetworkEnv environment,
  }) async {
    try {
      final entity = await WatchOnlyWalletEntity.parse(
        input,
        environment: environment,
      );
      return Ok(entity);
    } on WatchOnlyNetworkMismatchException {
      return const Err(NetworkMismatchFailure());
    } catch (error) {
      if (error is Error) rethrow;
      // Do not log pasted input or a foreign exception containing it.
      log.warning('Failed to parse watch-only input');
      return const Err(InvalidFormatFailure());
    }
  }
}
