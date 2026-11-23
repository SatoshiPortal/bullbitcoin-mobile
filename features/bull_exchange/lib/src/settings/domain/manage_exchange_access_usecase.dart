import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

typedef ExchangeAccessActions = ({
  ExchangeAccess Function() current,
  Stream<ExchangeAccess> Function() watch,
  Future<Result<void, ExchangeFailure>> Function() enable,
  Future<Result<void, ExchangeFailure>> Function() signOut,
  Future<Result<void, ExchangeFailure>> Function() resolve,
});

class WatchExchangeAccessUsecase {
  final ExchangeAccessActions _actions;

  const WatchExchangeAccessUsecase(this._actions);

  ExchangeAccess get current => _actions.current();
  Stream<ExchangeAccess> execute() => _actions.watch();
}

class ManageExchangeAccessUsecase {
  final ExchangeAccessActions _actions;

  const ManageExchangeAccessUsecase(this._actions);

  @useResult
  Future<Result<void, ExchangeFailure>> execute(bool enabled) =>
      enabled ? _actions.enable() : _actions.signOut();

  @useResult
  Future<Result<void, ExchangeFailure>> retry() => _actions.resolve();
}
