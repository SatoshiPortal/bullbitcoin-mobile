import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_user_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:meta/meta.dart';

/// Reads the signed-in account.
///
/// The repository already sanitizes and logged the raw reason; this only lifts
/// the core family into the feature's own so no foreign type reaches the cubit.
class GetExchangeAccountUsecase {
  final ExchangeUserRepository _mainnetExchangeUserRepository;
  final ExchangeUserRepository _testnetExchangeUserRepository;
  final SettingsRepository _settingsRepository;

  const GetExchangeAccountUsecase({
    required this._mainnetExchangeUserRepository,
    required this._testnetExchangeUserRepository,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<UserSummary, ExchangeFailure>> execute() async {
    final settings = await _settingsRepository.fetch();
    final repo = settings.environment.isTestnet
        ? _testnetExchangeUserRepository
        : _mainnetExchangeUserRepository;

    final result = await repo.getUserSummary();

    return result.mapErr(
      (failure) => switch (failure) {
        ExchangeUserNotAuthenticatedFailure() =>
          ExchangeNotAuthenticatedFailure(failure.logMessage),
        _ => ExchangeAccountUnavailableFailure(failure.logMessage),
      },
    );
  }
}
