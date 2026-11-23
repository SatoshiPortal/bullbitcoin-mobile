import 'package:exchange/exchange.dart';

RecipientsFailure mapVirtualIbanFailure(ExchangeFailure failure) =>
    switch (failure) {
      ExchangeNotAuthenticatedFailure() =>
        const RecipientsNotAuthenticatedFailure(),
      ExchangeNetworkFailure() => const RecipientsNetworkFailure(),
      ExchangeVirtualIbanNotAvailableFailure() =>
        const RecipientsVirtualIbanNotAvailableFailure(),
      ExchangeEuResidencyRequiredFailure() =>
        const RecipientsEuResidencyRequiredFailure(),
      ExchangeCredentialReadFailure() => const RecipientsUnexpectedFailure(
        'Exchange credential unavailable',
      ),
      _ => RecipientsUnexpectedFailure(failure.logMessage),
    };
