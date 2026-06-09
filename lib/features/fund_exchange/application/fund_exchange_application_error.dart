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
  final Map<String, String>? messageData;

  const FetchFundingDetailsFailed({
    required this.message,
    this.code,
    this.messageData,
  });
}

class FetchInstitutionsFailed extends FundExchangeApplicationError {
  final String message;
  final String? code;
  final Map<String, String>? messageData;
  final bool emptyList;

  const FetchInstitutionsFailed({
    required this.message,
    this.code,
    this.messageData,
    this.emptyList = false,
  });

  const FetchInstitutionsFailed.emptyList()
    : message = '',
      code = null,
      messageData = null,
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
