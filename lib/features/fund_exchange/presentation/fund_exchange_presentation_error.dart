import 'package:bb_mobile/features/fund_exchange/application/fund_exchange_application_error.dart';

sealed class FundExchangePresentationError implements Exception {
  const FundExchangePresentationError();

  static FundExchangePresentationError fromApplicationError(
    FundExchangeApplicationError error,
  ) {
    return switch (error) {
      FetchFundingDetailsFailed() => const LoadFundingDetailsFailed(),
      FetchInstitutionsFailed() => const LoadInstitutionsFailed(),
      InvalidInstitution() => const LoadInstitutionsFailed(),
      UnsupportedJurisdiction() => const UnexpectedError(),
      FundExchangeUnknownError() => const UnexpectedError(),
    };
  }
}

class LoadFundingDetailsFailed extends FundExchangePresentationError {
  const LoadFundingDetailsFailed();
}

class LoadInstitutionsFailed extends FundExchangePresentationError {
  const LoadInstitutionsFailed();
}

class UnexpectedError extends FundExchangePresentationError {
  const UnexpectedError();
}
