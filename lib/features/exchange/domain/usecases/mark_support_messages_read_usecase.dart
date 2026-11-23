import '../exchange_access.dart';
import '../repositories/exchange_access_repository.dart';

import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Marks every support chat message of the signed-in user as read.
class MarkSupportMessagesReadUsecase {
  final Exchange _exchange;
  final ExchangeAccessRepository _access;

  const MarkSupportMessagesReadUsecase({
    required this._exchange,
    required this._access,
  });

  @useResult
  Future<Result<void, ExchangeFailure>> execute() async {
    if (!_signedIn) return const Err(ExchangeNotAuthenticatedFailure());
    final epoch = _access.epoch;
    final result = await _exchange.markSupportMessagesRead();
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
