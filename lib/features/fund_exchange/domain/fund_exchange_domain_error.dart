sealed class FundExchangeDomainError implements Exception {
  const FundExchangeDomainError();
}

class JurisdictionNotSupported extends FundExchangeDomainError {
  final String jurisdiction;

  const JurisdictionNotSupported({required this.jurisdiction});
}

class InvalidInstitutionCode extends FundExchangeDomainError {
  const InvalidInstitutionCode();
}

class InvalidInstitutionName extends FundExchangeDomainError {
  const InvalidInstitutionName();
}
