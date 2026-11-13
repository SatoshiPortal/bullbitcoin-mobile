import 'package:bb_mobile/features/exchange/domain/exchange_access.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/repositories/exchange_auth_repository.dart';
import 'package:primitives/primitives.dart';

abstract interface class ExchangeAccessRepository {
  ExchangeAccess get current;
  int get epoch;
  Stream<ExchangeAccess> watch();
  Future<Result<void, ExchangeFailure>> resolve();
  Future<Result<void, ExchangeFailure>> enable({
    bool onlyIfUnset = false,
    bool choice = true,
    bool forSupport = false,
  });
  Future<Result<void, ExchangeFailure>> signOut();
  Future<Result<void, ExchangeFailure>> runAuthenticated(
    Future<Result<void, ExchangeFailure>> Function() operation,
  );
  Future<Result<void, ExchangeFailure>> expireSession({
    required int epoch,
    required bool isTestnet,
  });
  Future<Result<void, ExchangeFailure>> completeAuthentication({
    required ExchangeAuthRepository authRepository,
    required bool isTestnet,
    required bool Function() isCurrent,
  });
}
