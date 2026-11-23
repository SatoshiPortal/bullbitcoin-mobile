import '../setup/exchange_access_lifecycle.dart';

import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

import 'read_exchange_environment.dart';
import 'expire_exchange_session_usecase.dart';

/// Only a current, server-rejected request may expire a credential.
class GetExchangeAccountUsecase {
  const GetExchangeAccountUsecase({
    required this._exchange,
    required Preferences settingsRepository,
    required this._access,
    required this._expire,
  }) : _settings = settingsRepository;

  final Exchange _exchange;
  final Preferences _settings;
  final ExchangeAccessLifecycle _access;
  final ExpireExchangeSessionUsecase _expire;

  Future<Result<UserSummary, ExchangeFailure>> execute() async {
    if (_access.session case final session?) {
      final epoch = session.epoch;
      final environment = await readExchangeEnvironment(
        _settings,
        ExchangeAccountUnavailableFailure.new,
      );
      if (_access.session != session) {
        return const Err(ExchangeOperationStaleFailure());
      }
      final bool isTestnet;
      switch (environment) {
        case Ok(:final value):
          isTestnet = value == Environment.testnet;
        case Err(:final failure):
          return Err(failure);
      }
      final result = await _exchange.getAccount(
        isTestnet ? ExchangeEnvironment.testnet : ExchangeEnvironment.mainnet,
      );
      if (_access.session != session) {
        return const Err(ExchangeOperationStaleFailure());
      }
      if (result case Err(failure: ExchangeSessionRejectedFailure())) {
        final expired = await _expire.execute(
          epoch: epoch,
          isTestnet: isTestnet,
        );
        if (expired case Err(:final failure)) return Err(failure);
      }
      return result;
    }
    return const Err(ExchangeNotAuthenticatedFailure());
  }
}
