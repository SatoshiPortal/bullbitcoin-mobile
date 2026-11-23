import 'package:bb_mobile/core/exchange/domain/entity/exchange_api_key.dart';
import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';

abstract interface class ExchangeAuthRepository {
  @useResult
  Future<Result<ExchangeApiKey, ExchangeFailure>> generateApiKey();
}
