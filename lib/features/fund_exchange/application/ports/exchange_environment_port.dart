abstract class ExchangeEnvironmentPort {
  Future<bool> get isTestnet;
}

/// The concrete environment has no exchange backend.
final class UnsupportedExchangeNetworkException implements Exception {
  const UnsupportedExchangeNetworkException();
}
