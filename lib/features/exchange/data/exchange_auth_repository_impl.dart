import 'package:bb_mobile/core/exchange/data/mappers/exchange_api_key_mapper.dart';
import 'package:bb_mobile/core/exchange/data/models/api_key_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/exchange_api_key.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/exchange/data/exchange_web_auth_datasource.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/repositories/exchange_auth_repository.dart';

final class ExchangeAuthRepositoryImpl implements ExchangeAuthRepository {
  final ExchangeWebAuthDatasource _datasource;

  const ExchangeAuthRepositoryImpl({required this._datasource});

  @override
  Future<Result<ExchangeApiKey, ExchangeFailure>> generateApiKey() async {
    try {
      final response = await _datasource.generateApiKeyResponse();
      if (ExchangeApiKeyModel.isAuthenticationDeferred(response)) {
        return const Err(ExchangeAuthenticationDeferredFailure());
      }
      final model = ExchangeApiKeyModel.tryFromAuthResponse(response);
      if (model == null || !model.isActive) {
        return const Err(ExchangeAuthenticationFailure());
      }
      return ExchangeApiKeyMapper.toDomain(model)
          .mapErr((_) => const ExchangeAuthenticationFailure());
    } on Exception {
      // Platform errors may contain cookies or the entire response.
      return const Err(ExchangeAuthenticationFailure());
    }
  }
}
