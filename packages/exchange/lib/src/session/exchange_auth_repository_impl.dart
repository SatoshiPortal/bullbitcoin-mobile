import 'package:primitives/primitives.dart';

import '../domain/entities/exchange_api_key.dart';
import '../domain/exchange_failure.dart';
import '../setup/exchange_credentials.dart';
import 'exchange_auth_repository.dart';
import 'exchange_web_auth_datasource.dart';

final class ExchangeAuthRepositoryImpl implements ExchangeAuthRepository {
  final ExchangeWebAuthDatasource _datasource;

  const ExchangeAuthRepositoryImpl({required this._datasource});

  @override
  Future<Result<ExchangeApiKey, ExchangeFailure>> generateApiKey() async {
    try {
      final response = await _datasource.generateApiKeyResponse();
      return ExchangeCredentials.decodeAuthentication(response);
    } on Exception {
      // Platform errors may contain cookies or the entire response.
      return const Err(ExchangeAuthenticationFailure());
    }
  }
}
