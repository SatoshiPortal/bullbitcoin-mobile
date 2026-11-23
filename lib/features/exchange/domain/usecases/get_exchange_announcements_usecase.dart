import 'package:exchange/setup.dart';

import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/exchange/domain/read_exchange_environment.dart';
import 'package:meta/meta.dart';

/// Reads the announcement banner content. The repository sanitizes; this only
/// lifts the core failure into the feature's family.
class GetExchangeAnnouncementsUsecase {
  final Exchange _exchange;
  final Preferences _settingsRepository;
  final ExchangeAccessLifecycle _access;

  const GetExchangeAnnouncementsUsecase({
    required this._exchange,
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
    final result = await _exchange.listAnnouncements(
      environment == Environment.testnet
          ? ExchangeEnvironment.testnet
          : ExchangeEnvironment.mainnet,
    );

    if (_access.epoch != epoch) {
      return const Err(ExchangeOperationStaleFailure());
    }
    return result.mapErr(
      (failure) => ExchangeAnnouncementsUnavailableFailure(failure.logMessage),
    );
  }
}
