import 'package:primitives/primitives.dart' show Result;
import 'package:bb_mobile/features/exchange_access/domain/exchange_access.dart';
import 'package:bb_mobile/features/exchange_access/domain/exchange_access_failure.dart';
import 'package:meta/meta.dart';

abstract interface class ExchangeAccessRepository {
  @useResult
  Future<Result<Map<bool, ExchangeAccess>, ExchangeAccessFailure>> read();
  @useResult
  Future<Result<void, ExchangeAccessFailure>> write(
    Map<bool, ExchangeAccess> values,
  );
}
