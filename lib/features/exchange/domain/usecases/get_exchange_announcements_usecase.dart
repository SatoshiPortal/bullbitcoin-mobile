import '../repositories/exchange_access_repository.dart';
import '../exchange_access.dart';
import 'package:bb_mobile/core/exchange/domain/entity/announcement.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/read_exchange_environment.dart';
import 'package:meta/meta.dart';

/// Reads the announcement banner content. The repository sanitizes; this only
/// lifts the core failure into the feature's family.
class GetExchangeAnnouncementsUsecase {
  final ExchangeUserRepository _mainnetExchangeUserRepository;
  final ExchangeUserRepository _testnetExchangeUserRepository;
  final SettingsRepository _settingsRepository;
  final ExchangeAccessRepository _access;

  const GetExchangeAnnouncementsUsecase({
    required this._mainnetExchangeUserRepository,
    required this._testnetExchangeUserRepository,
    required this._settingsRepository,
    required this._access,
  });

  @useResult
  Future<Result<List<Announcement>, ExchangeFailure>> execute() async {
    if (_access.current is! ExchangeAccessEnabled ||
        (_access.current as ExchangeAccessEnabled).session !=
            ExchangeAccessSession.signedIn) {
      return const Err(ExchangeNotAuthenticatedFailure());
    }
    final epoch = _access.epoch;
    final Environment environment;
    final readEnvironment = await readExchangeEnvironment(
      _settingsRepository,
      ExchangeAnnouncementsUnavailableFailure.new,
    );
    if (_access.epoch != epoch) {
      return const Err(ExchangeOperationStaleFailure());
    }
    switch (readEnvironment) {
      case Ok(:final value):
        environment = value;
      case Err(:final failure):
        return Err(failure);
    }
    if (_access.epoch != epoch) {
      return const Err(ExchangeOperationStaleFailure());
    }
    final repo = environment.isTestnet
        ? _testnetExchangeUserRepository
        : _mainnetExchangeUserRepository;

    final result = await repo.listAnnouncements();

    if (_access.epoch != epoch) {
      return const Err(ExchangeOperationStaleFailure());
    }
    return result.mapErr(
      (failure) => ExchangeAnnouncementsUnavailableFailure(failure.logMessage),
    );
  }
}
