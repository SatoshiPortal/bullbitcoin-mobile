import 'package:bb_mobile/core/exchange/domain/entity/exchange_api_key.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:meta/meta.dart';

abstract interface class ExchangeAuthRepository {
  @useResult
  Future<Result<ExchangeApiKey, ExchangeFailure>> generateApiKey();
}
