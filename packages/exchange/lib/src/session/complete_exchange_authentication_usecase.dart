import 'package:primitives/primitives.dart';

import '../domain/exchange_failure.dart';
import '../setup/exchange_access_lifecycle.dart';
import 'exchange_auth_repository.dart';

/// WebView-scoped capability; the repository serializes credential changes.
class CompleteExchangeAuthenticationUsecase {
  CompleteExchangeAuthenticationUsecase({
    required ExchangeAuthRepository authRepository,
    required this._access,
    required this._isTestnet,
  }) : _auth = authRepository;

  final ExchangeAuthRepository _auth;
  final ExchangeAccessLifecycle _access;
  final bool _isTestnet;
  Future<Result<void, ExchangeFailure>>? _inFlight;

  Future<Result<void, ExchangeFailure>> execute({
    required bool Function() isCurrent,
  }) => _inFlight ??= _access
      .completeAuthentication(
        generateApiKey: _auth.generateApiKey,
        isTestnet: _isTestnet,
        isCurrent: isCurrent,
      )
      .whenComplete(() => _inFlight = null);
}
