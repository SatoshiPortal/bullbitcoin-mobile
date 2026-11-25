import '../domain/exchange_access.dart';
import 'exchange_access_lifecycle.dart';

/// An access lifecycle that stays in [current]; any other call throws.
ExchangeAccessLifecycle fixedAccessForTesting(ExchangeAccess current) =>
    _FixedAccess(current);

final class _FixedAccess implements ExchangeAccessLifecycle {
  @override
  final ExchangeAccess current;

  _FixedAccess(this.current);

  @override
  ExchangeSession? get session => current.signedInSession;

  @override
  Stream<ExchangeAccess> watch() => Stream.value(current);

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected access call ${invocation.memberName}');
}
