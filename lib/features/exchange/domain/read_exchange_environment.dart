import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// The environment every exchange call is scoped to.
///
/// The shared settings repository still throws, so this is its boundary for
/// the exchange use-cases: they promise a `Result`, and the cubit has no catch
/// left to stop a throw. [onFailure] builds the caller's own variant, so a
/// failed read reads as the operation that could not run, not as a generic
/// error.
@useResult
Future<Result<Environment, ExchangeFailure>> readExchangeEnvironment(
  SettingsRepository settingsRepository,
  ExchangeFailure Function([String? logMessage]) onFailure,
) async {
  try {
    return Ok((await settingsRepository.fetch()).environment);
  } catch (e, st) {
    // Type only, matching the repositories.
    log.warning('Could not read the environment: ${e.runtimeType}', trace: st);
    return Err(onFailure('settings fetch failed: ${e.runtimeType}'));
  }
}
