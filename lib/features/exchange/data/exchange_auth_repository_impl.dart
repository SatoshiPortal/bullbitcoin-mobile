import 'package:exchange/setup.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/exchange/data/exchange_web_auth_datasource.dart';
import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/exchange/domain/repositories/exchange_auth_repository.dart';

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
