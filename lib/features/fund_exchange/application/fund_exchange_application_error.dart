import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_domain_error.dart';

sealed class FundExchangeApplicationError implements Exception {
  const FundExchangeApplicationError();

  static FundExchangeApplicationError fromDomainError(
    FundExchangeDomainError error,
  ) {
    return switch (error) {
      JurisdictionNotSupported(:final jurisdiction) => UnsupportedJurisdiction(
        jurisdiction: jurisdiction,
      ),
      InvalidInstitutionCode() => const InvalidInstitution(field: 'code'),
      InvalidInstitutionName() => const InvalidInstitution(field: 'name'),
    };
  }
}

class InvalidInstitution extends FundExchangeApplicationError {
  final String field;

  const InvalidInstitution({required this.field});
}

class UnsupportedJurisdiction extends FundExchangeApplicationError {
  final String jurisdiction;

  const UnsupportedJurisdiction({required this.jurisdiction});
}

class FetchFundingDetailsFailed extends FundExchangeApplicationError {
  final String message;
  final String? code;

  const FetchFundingDetailsFailed({required this.message, this.code});

  bool get isOptionUnavailable =>
      code == 'ERR_RCP_PO404' ||
      code == 'ERR_RCP_POSINPE404' ||
      code == 'ERR_ORD_PO404';
}

class FetchInstitutionsFailed extends FundExchangeApplicationError {
  final String message;
  final bool emptyList;

  const FetchInstitutionsFailed({
    required this.message,
    this.emptyList = false,
  });

  const FetchInstitutionsFailed.emptyList()
    : message = '',
      emptyList = true;
}

class FundExchangeUnknownError extends FundExchangeApplicationError {
  final String message;

  const FundExchangeUnknownError({required this.message});
}

class ResponsibilityConsentRegistrationFailed
    extends FundExchangeApplicationError {
  final String message;

  const ResponsibilityConsentRegistrationFailed({required this.message});
}
