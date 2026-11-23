import 'package:exchange/setup.dart';
import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';

abstract interface class ExchangeAuthRepository {
  @useResult
  Future<Result<ExchangeApiKey, ExchangeFailure>> generateApiKey();
}
