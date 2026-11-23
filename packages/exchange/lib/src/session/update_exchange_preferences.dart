import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/user_summary.dart';
import '../domain/exchange_access.dart';
import '../domain/exchange_environment.dart';
import '../domain/exchange_failure.dart';
import '../domain/exchange_preferences_patch.dart';

typedef ReadExchangeSummary =
    Future<Result<UserSummary, ExchangeFailure>> Function(ExchangeEnvironment);

typedef WriteExchangePreferences =
    Future<Result<void, ExchangeFailure>> Function(
      ExchangeEnvironment, {
      String? language,
      String? currency,
      bool? dcaEnabled,
      String? autoBuyEnabled,
      bool? emailNotificationsEnabled,
    });

/// The only writer of account preferences (stop DCA, AutoBuy, DCA creation,
/// the preferences screen, the app currency sync).
///
/// The exchange's `saveUserPreferences` replaces the whole stored set, so
/// the patch is applied to a fresh summary of the same session and only the
/// fields that differ from it change; the others are sent as just read. A
/// patch the account already satisfies sends nothing. A failed summary read
/// aborts the write, and a request for a session that is no longer current
/// is refused.
class UpdateExchangePreferences {
  final ReadExchangeSummary _readSummary;
  final WriteExchangePreferences _write;
  final ExchangeSession? Function() _currentSession;

  const UpdateExchangePreferences({
    required ReadExchangeSummary readSummary,
    required WriteExchangePreferences write,
    required ExchangeSession? Function() currentSession,
  }) : _readSummary = readSummary,
       _write = write,
       _currentSession = currentSession;

  @useResult
  Future<Result<void, ExchangeFailure>> execute(
    ExchangeSession session,
    ExchangePreferencesPatch patch,
  ) async {
    if (_currentSession() != session) {
      return const Err(ExchangeOperationStaleFailure());
    }
    if (patch.isEmpty) return const Ok(null);

    final read = await _readSummary(session.environment);
    if (_currentSession() != session) {
      return const Err(ExchangeOperationStaleFailure());
    }
    final UserSummary summary;
    switch (read) {
      case Ok(:final value):
        summary = value;
      case Err(:final failure):
        return Err(switch (failure) {
          ExchangeNotAuthenticatedFailure() ||
          ExchangeNetworkFailure() => failure,
          _ => ExchangePreferencesSaveFailure(failure.logMessage),
        });
    }

    final changes = patch.changesFrom(summary);
    if (changes.isEmpty) return const Ok(null);

    final result = await _write(
      session.environment,
      language: changes.language ?? summary.language,
      currency: changes.currency ?? summary.currency,
      dcaEnabled: changes.dcaEnabled ?? summary.dca.isActive,
      autoBuyEnabled: (changes.autoBuyEnabled ?? summary.autoBuy.isActive)
          .toString(),
      emailNotificationsEnabled:
          changes.emailNotificationsEnabled ??
          summary.emailNotificationsEnabled,
    );
    return result.mapErr(
      (failure) => switch (failure) {
        ExchangeNetworkFailure() ||
        ExchangePreferencesSaveOutcomeUnknownFailure() => failure,
        _ => ExchangePreferencesSaveFailure(failure.logMessage),
      },
    );
  }
}
