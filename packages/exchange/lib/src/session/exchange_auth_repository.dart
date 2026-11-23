import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

import '../domain/entities/exchange_api_key.dart';
import '../domain/exchange_failure.dart';

abstract interface class ExchangeAuthRepository {
  @useResult
  Future<Result<ExchangeApiKey, ExchangeFailure>> generateApiKey();
}
