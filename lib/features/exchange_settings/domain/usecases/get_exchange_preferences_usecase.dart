import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/entities/exchange_preferences.dart';
import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Wraps the shared exchange use-case, which still throws, so the cubit above
/// can switch on a `Result` instead of catching.
class GetExchangePreferencesUsecase {
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;

  const GetExchangePreferencesUsecase({
    required this._getExchangeUserSummaryUsecase,
  });

  @useResult
  Future<Result<ExchangePreferences, ExchangeSettingsFailure>> execute() async {
    try {
      final summary = await _getExchangeUserSummaryUsecase.execute();
      return Ok(
        ExchangePreferences(
          language: summary.language,
          currency: summary.currency,
          emailNotificationsEnabled: summary.emailNotificationsEnabled,
        ),
      );
    } on Error {
      rethrow;
    } on GetExchangeUserSummaryCredentialException catch (e) {
      log.info('Exchange account credential refused: ${e.runtimeType}');
      return const Err(
        ExchangeSettingsAccountUnavailableFailure(
          'Exchange credential unavailable',
        ),
      );
    } catch (e, st) {
      log.severe(message: 'getExchangeUserSummary failed', error: e, trace: st);
      return Err(
        ExchangeSettingsAccountUnavailableFailure(
          'getExchangeUserSummary failed: ${e.runtimeType}',
        ),
      );
    }
  }
}
