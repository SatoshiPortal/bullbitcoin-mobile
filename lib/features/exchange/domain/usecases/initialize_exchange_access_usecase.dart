import 'package:meta/meta.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_session.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange_access/public/exchange_access_facade.dart';

class InitializeExchangeAccessUsecase {
  InitializeExchangeAccessUsecase(this._session, this._access);

  final ExchangeSession _session;
  final ExchangeAccessFacade _access;
  int _generation = 0;

  @useResult
  Future<Result<void, ExchangeFailure>> execute({
    required bool isTestnet,
  }) async {
    final generation = ++_generation;
    _access.suspend();
    final accessGeneration = _access.generation;
    _session.publish(ExchangeSessionStatus.resolving);
    await _access.settle();
    if (generation != _generation || accessGeneration != _access.generation) {
      return const Err(ExchangeUnexpectedFailure());
    }
    final session = await _session.resolve(isTestnet: isTestnet);
    if (generation != _generation || accessGeneration != _access.generation) {
      return const Err(ExchangeUnexpectedFailure());
    }
    final result = await _access.initialize(
      isTestnet: isTestnet,
      session: switch (session) {
        ExchangeSessionStatus.resolving => ExchangeSessionFact.resolving,
        ExchangeSessionStatus.anonymous => ExchangeSessionFact.anonymous,
        ExchangeSessionStatus.authenticated =>
          ExchangeSessionFact.authenticated,
        ExchangeSessionStatus.expired => ExchangeSessionFact.expired,
        ExchangeSessionStatus.unavailable => ExchangeSessionFact.unavailable,
        ExchangeSessionStatus.networkUnavailable =>
          ExchangeSessionFact.networkUnavailable,
      },
    );
    return switch (result) {
      Ok(value: ExchangeAccessOutcome.applied) => const Ok(null),
      _ => const Err(ExchangeUnexpectedFailure()),
    };
  }
}
