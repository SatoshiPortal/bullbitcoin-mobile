import 'package:exchange/exchange.dart';

import 'fund_exchange_failure.dart';

FundExchangeFailure mapFundingFailure(ExchangeFailure failure) =>
    switch (failure) {
      ExchangeNotAuthenticatedFailure() =>
        const FundExchangeNotAuthenticatedFailure(),
      ExchangeUnsupportedNetworkFailure() =>
        const FundExchangeUnsupportedNetworkFailure(),
      ExchangeNetworkFailure() => FundExchangeNetworkFailure(
        failure.logMessage,
      ),
      ExchangeConsentRegistrationFailure() =>
        FundExchangeConsentRegistrationFailure(failure.logMessage),
      ExchangeFundingFailure(:final problem, :final logMessage) =>
        switch (problem) {
          ExchangeFundingProblem.paymentOptionUnavailable =>
            FundExchangePaymentOptionUnavailableFailure(logMessage),
          ExchangeFundingProblem.optionNotPermitted =>
            FundExchangeOptionNotPermittedFailure(logMessage),
          ExchangeFundingProblem.sinpeNotRegistered =>
            FundExchangeSinpeNotRegisteredFailure(logMessage),
          ExchangeFundingProblem.kycIncomplete =>
            FundExchangeKycIncompleteFailure(logMessage),
          ExchangeFundingProblem.copRequestInvalid =>
            FundExchangeCopRequestInvalidFailure(logMessage),
          ExchangeFundingProblem.sepaVirtualPaymentInactive =>
            FundExchangeSepaVirtualPaymentInactiveFailure(logMessage),
          ExchangeFundingProblem.requestInvalid =>
            FundExchangeRequestInvalidFailure(logMessage),
          ExchangeFundingProblem.noInstitutions =>
            FundExchangeNoInstitutionsFailure(logMessage),
        },
      _ => FundExchangeUnexpectedFailure(failure.logMessage),
    };
