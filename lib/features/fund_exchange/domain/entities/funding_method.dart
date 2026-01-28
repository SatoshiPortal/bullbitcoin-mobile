enum FundingMethod {
  emailETransfer(queryParam: 'email-e-transfer'),
  bankTransferWire(queryParam: 'bank-transfer-wire'),
  onlineBillPayment(queryParam: 'online-bill-payment'),
  canadaPost(queryParam: 'canada-post'),
  instantSepa(queryParam: 'instant-sepa'),
  regularSepa(queryParam: 'regular-sepa'),
  confidentialSepa(queryParam: 'confidential-sepa'),
  speiTransfer(queryParam: 'spei-transfer'),
  sinpe(queryParam: 'sinpe'),
  crIbanCrc(queryParam: 'cr-iban-crc'),
  crIbanUsd(queryParam: 'cr-iban-usd'),
  arsBankTransfer(queryParam: 'ars-bank-transfer');

  final String queryParam;
  const FundingMethod({required this.queryParam});

  static FundingMethod? fromQueryParam(String queryParam) {
    try {
      return FundingMethod.values.firstWhere(
        (method) => method.queryParam == queryParam,
      );
    } catch (e) {
      return null;
    }
  }
}
