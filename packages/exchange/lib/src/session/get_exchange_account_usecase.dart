import '../setup/exchange_access_lifecycle.dart';

import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

import 'expire_exchange_session_usecase.dart';

/// Reads the account of [execute]'s session. A session that is no longer
/// current is refused, before the request and after it; only a current,
/// server-rejected request may expire a credential.
class GetExchangeAccountUsecase {
  const GetExchangeAccountUsecase({
    required this._exchange,
    required this._access,
    required this._expire,
  });

  final Exchange _exchange;
  final ExchangeAccessLifecycle _access;
  final ExpireExchangeSessionUsecase _expire;

  Future<Result<UserSummary, ExchangeFailure>> execute(
    ExchangeSession session,
  ) async {
    if (_access.session != session) {
      return const Err(ExchangeOperationStaleFailure());
    }
    final result = await _exchange.getAccount(session.environment);
    if (_access.session != session) {
      return const Err(ExchangeOperationStaleFailure());
    }
    if (result case Err(failure: ExchangeSessionRejectedFailure())) {
      final expired = await _expire.execute(
        epoch: session.epoch,
        isTestnet: session.environment == ExchangeEnvironment.testnet,
      );
      if (expired case Err(:final failure)) return Err(failure);
    }
    return result;
  }
}
