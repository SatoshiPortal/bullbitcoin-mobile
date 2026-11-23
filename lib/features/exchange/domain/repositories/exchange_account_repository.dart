import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart' show Result;
import 'package:meta/meta.dart';

abstract interface class ExchangeAccountRepository {
  @useResult
  Future<Result<UserSummary, ExchangeFailure>> getAccount();
}
