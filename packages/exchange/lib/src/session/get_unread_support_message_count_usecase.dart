import '../setup/exchange_access_lifecycle.dart';

import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Reads how many support chat messages the signed-in user has not read.
class GetUnreadSupportMessageCountUsecase {
  final Exchange _exchange;
  final ExchangeAccessLifecycle _access;

  const GetUnreadSupportMessageCountUsecase({
    required this._exchange,
    required this._access,
  });

  @useResult
  Future<Result<int, ExchangeFailure>> execute() async {
    if (!_signedIn) return const Err(ExchangeNotAuthenticatedFailure());
    final epoch = _access.epoch;
    final result = await _exchange.getUnreadSupportMessageCount();
    if (_access.epoch != epoch || !_signedIn) {
      return const Err(ExchangeOperationStaleFailure());
    }
    return result;
  }

  bool get _signedIn => switch (_access.current) {
    ExchangeAccessEnabled(session: ExchangeAccessSession.signedIn) => true,
    _ => false,
  };
}
