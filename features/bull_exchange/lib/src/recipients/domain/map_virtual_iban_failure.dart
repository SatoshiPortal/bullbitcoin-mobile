import 'package:exchange/exchange.dart';

ExchangeFailure mapVirtualIbanFailure(ExchangeFailure failure) =>
    switch (failure) {
      ExchangeNotAuthenticatedFailure() =>
        const ExchangeNotAuthenticatedFailure(),
      ExchangeNetworkFailure() => const ExchangeNetworkFailure(),
      ExchangeVirtualIbanNotAvailableFailure() =>
        const ExchangeVirtualIbanNotAvailableFailure(),
      ExchangeEuResidencyRequiredFailure() =>
        const ExchangeEuResidencyRequiredFailure(),
      ExchangeCredentialReadFailure() => const ExchangeUnexpectedFailure(
        'Exchange credential unavailable',
      ),
      _ => ExchangeUnexpectedFailure(failure.logMessage),
    };
