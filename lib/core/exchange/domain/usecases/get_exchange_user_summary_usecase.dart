import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';

/// Legacy throwing adapter over [ExchangeUserRepository].
///
/// The repository is the sanitizing boundary now. This use-case exists only so
/// the features that have not migrated yet keep their exception-based contract;
/// migrated features take the repository directly. Delete it once the last
/// caller is gone (#1895).
class GetExchangeUserSummaryUsecase {
  final ExchangeUserRepository _mainnetExchangeUserRepository;
  final ExchangeUserRepository _testnetExchangeUserRepository;
  final SettingsRepository _settingsRepository;

  GetExchangeUserSummaryUsecase({
    required this._mainnetExchangeUserRepository,
    required this._testnetExchangeUserRepository,
    required this._settingsRepository,
  });

  Future<UserSummary> execute() async {
    // Kept inside the legacy contract: callers (autobuy, limit_orders) catch
    // GetExchangeUserSummaryException specifically, so a settings failure must
    // surface as one, not as a raw exception. Type only in the message.
    final SettingsEntity settings;
    try {
      settings = await _settingsRepository.fetch();
    } catch (e) {
      throw GetExchangeUserSummaryException(
        'settings fetch failed: ${e.runtimeType}',
      );
    }
    final repo = settings.environment.isTestnet
        ? _testnetExchangeUserRepository
        : _mainnetExchangeUserRepository;

    return switch (await repo.getUserSummary()) {
      Ok(:final value) => value,
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
