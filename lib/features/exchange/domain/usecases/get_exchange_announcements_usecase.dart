import 'package:bb_mobile/core/exchange/domain/entity/announcement.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:meta/meta.dart';

/// Reads the announcement banner content. The repository sanitizes; this only
/// lifts the core failure into the feature's family.
class GetExchangeAnnouncementsUsecase {
  final ExchangeUserRepository _mainnetExchangeUserRepository;
  final ExchangeUserRepository _testnetExchangeUserRepository;
  final SettingsRepository _settingsRepository;

  const GetExchangeAnnouncementsUsecase({
    required this._mainnetExchangeUserRepository,
    required this._testnetExchangeUserRepository,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<List<Announcement>, ExchangeFailure>> execute() async {
    final settings = await _settingsRepository.fetch();
    final repo = settings.environment.isTestnet
        ? _testnetExchangeUserRepository
        : _mainnetExchangeUserRepository;

    final result = await repo.listAnnouncements();

    return result.mapErr(
      (failure) => ExchangeAnnouncementsUnavailableFailure(failure.logMessage),
    );
  }
}
