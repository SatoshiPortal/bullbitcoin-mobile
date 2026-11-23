import '../setup/exchange_access_lifecycle.dart';

import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';

import 'read_exchange_environment.dart';

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
    final session = _access.session;
    if (session == null) {
      return const Err(ExchangeNotAuthenticatedFailure());
    }
    final Environment environment;
    final readEnvironment = await readExchangeEnvironment(
      _settingsRepository,
      ExchangeAnnouncementsUnavailableFailure.new,
    );
    if (_access.session != session) {
      return const Err(ExchangeOperationStaleFailure());
    }
    switch (readEnvironment) {
      case Ok(:final value):
        environment = value;
      case Err(:final failure):
        return Err(failure);
    }
    if (_access.session != session) {
      return const Err(ExchangeOperationStaleFailure());
    }
    final result = await _exchange.listAnnouncements(
      environment == Environment.testnet
          ? ExchangeEnvironment.testnet
          : ExchangeEnvironment.mainnet,
    );

    if (_access.session != session) {
      return const Err(ExchangeOperationStaleFailure());
    }
    return result.mapErr(
      (failure) => ExchangeAnnouncementsUnavailableFailure(failure.logMessage),
    );
  }
}
