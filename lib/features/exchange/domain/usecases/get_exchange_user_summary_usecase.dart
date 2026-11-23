import 'package:primitives/legacy_exceptions.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

/// Legacy throwing adapter over the Exchange account summary.
///
/// The repository is the sanitizing boundary now. This use-case exists only so
/// the features that have not migrated yet keep their exception-based contract;
/// migrated features use [Exchange] directly. Delete it once the last
/// caller is gone (#1895).
class GetExchangeUserSummaryUsecase {
  final Exchange _exchange;
  final Preferences _settingsRepository;

  GetExchangeUserSummaryUsecase({
    required this._exchange,
    required this._settingsRepository,
  });

  Future<UserSummary> execute() async {
    // Kept inside the legacy contract: callers (autobuy, limit_orders) catch
    // GetExchangeUserSummaryException specifically, so a settings failure must
    // surface as one, not as a raw exception. Type only in the message.
    final SettingsEntity settings;
    try {
      settings = (await _settingsRepository.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      );
    } on Error {
      rethrow;
    } catch (e) {
      throw GetExchangeUserSummaryException(
        'settings fetch failed: ${e.runtimeType}',
      );
    }
    final environment = settings.environment.requireHistoricalTestnet()
        ? ExchangeEnvironment.testnet
        : ExchangeEnvironment.mainnet;

    return switch (await _exchange.getUserSummary(environment)) {
      Ok(:final value) => value,
      Err(failure: final ExchangeNotAuthenticatedFailure failure) =>
        throw GetExchangeUserSummaryCredentialException(
          failure.runtimeType.toString(),
        ),
      Err(failure: final ExchangeCredentialReadFailure failure) =>
        throw GetExchangeUserSummaryCredentialException(
          failure.runtimeType.toString(),
        ),
      // The raw reason was already logged at the repository boundary.
      Err(:final failure) => throw GetExchangeUserSummaryException(
        failure.logMessage ?? failure.runtimeType.toString(),
      ),
    };
  }
}

class GetExchangeUserSummaryException extends BullException {
  GetExchangeUserSummaryException(super.message);
}

/// Preserves typed credential refusals within the legacy account contract.
final class GetExchangeUserSummaryCredentialException
    extends GetExchangeUserSummaryException {
  GetExchangeUserSummaryCredentialException(super.message);
}
