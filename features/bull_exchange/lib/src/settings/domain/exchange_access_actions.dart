import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// What the host app lets the access settings do with the exchange access.
typedef ExchangeAccessActions = ({
  ExchangeAccess Function() current,
  Stream<ExchangeAccess> Function() watch,
  Future<Result<void, ExchangeFailure>> Function() enable,
  Future<Result<void, ExchangeFailure>> Function() signOut,
  Future<Result<void, ExchangeFailure>> Function() resolve,
});
