import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/repositories/exchange_auth_repository.dart';
import 'package:meta/meta.dart';

/// Acquire and persist within the environment in which the web session began.
/// The credential stays local to this operation and never enters bloc state.
class CompleteExchangeAuthenticationUsecase {
  final ExchangeAuthRepository _authRepository;
  final ExchangeApiKeyRepository _apiKeyRepository;
  final bool _isTestnet;

  const CompleteExchangeAuthenticationUsecase({
    required this._authRepository,
    required this._apiKeyRepository,
    required this._isTestnet,
  });

  @useResult
  Future<Result<void, ExchangeFailure>> execute() async {
    final generated = await _authRepository.generateApiKey();
    return switch (generated) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => (await _apiKeyRepository.saveApiKey(
        value,
        isTestnet: _isTestnet,
      )).mapErr((failure) => ExchangeApiKeyStorageFailure(failure.logMessage)),
    };
  }
}
