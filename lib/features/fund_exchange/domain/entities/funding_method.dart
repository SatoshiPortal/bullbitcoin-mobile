enum FundingMethod {
  emailETransfer(queryParam: 'email-e-transfer'),
  bankTransferWire(queryParam: 'bank-transfer-wire'),
  onlineBillPayment(queryParam: 'online-bill-payment'),
  canadaPost(queryParam: 'canada-post'),
  sepaTransfer(queryParam: 'sepa-transfer'),
  speiTransfer(queryParam: 'spei-transfer'),
  sinpeTransfer(queryParam: 'sinpe-transfer'),
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
