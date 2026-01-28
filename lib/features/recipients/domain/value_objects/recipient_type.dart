/// VALUE OBJECT: recipient type
/// Value objects are immutable and defined by their attributes
/// They encapsulate validation and behavior related to the type itself
enum RecipientType {
  // CANADA
  interacEmailCad('INTERAC_EMAIL_CAD'),
  billPaymentCad('BILL_PAYMENT_CAD'),
  bankTransferCad('BANK_TRANSFER_CAD'),
  // EUROPE
  sepaEur('SEPA_EUR'),
  // EUROPE - Virtual IBAN (Confidential SEPA)
  frVirtualAccount('FR_VIRTUAL_ACCOUNT'), // Virtual IBAN account
  frPayee('FR_PAYEE'), // Payee for withdrawals from VIBAN
  cjPayee('CJ_PAYEE'), // Regular SEPA payee (Clear Junction)
  // MEXICO
  speiClabeMxn('SPEI_CLABE_MXN'),
  speiSmsMxn('SPEI_SMS_MXN'),
  speiCardMxn('SPEI_CARD_MXN'),
  // COSTA RICA
  sinpeIbanUsd('SINPE_IBAN_USD'),
  sinpeIbanCrc('SINPE_IBAN_CRC'),
  sinpeMovilCrc('SINPE_MOVIL_CRC'),
  // ARGENTINA
  cbuCvuArgentina('CBU_CVU_ARGENTINA'),
  // Colombia
  pseColombia('PSE_COLOMBIA_COP'),
  nequiColombia('NEQUI_COLOMBIA_COP');

  final String value;
  const RecipientType(this.value);

  static RecipientType fromValue(String value) {
    return RecipientType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw Exception('Unknown RecipientType: $value'),
    );
  }

  String get jurisdictionCode {
    switch (this) {
      case RecipientType.interacEmailCad:
      case RecipientType.billPaymentCad:
      case RecipientType.bankTransferCad:
        return 'CA';
      case RecipientType.sepaEur:
      case RecipientType.frVirtualAccount:
      case RecipientType.frPayee:
      case RecipientType.cjPayee:
        return 'EU';
      case RecipientType.speiClabeMxn:
      case RecipientType.speiSmsMxn:
      case RecipientType.speiCardMxn:
        return 'MX';
      case RecipientType.sinpeIbanUsd:
      case RecipientType.sinpeIbanCrc:
      case RecipientType.sinpeMovilCrc:
        return 'CR';
      case RecipientType.cbuCvuArgentina:
        return 'AR';
      case RecipientType.pseColombia:
        return 'CO';
      case RecipientType.nequiColombia:
        return 'CO';
    }
  }

  String get currencyCode {
    switch (this) {
      case RecipientType.interacEmailCad:
      case RecipientType.billPaymentCad:
      case RecipientType.bankTransferCad:
        return 'CAD';
      case RecipientType.sepaEur:
      case RecipientType.frVirtualAccount:
      case RecipientType.frPayee:
      case RecipientType.cjPayee:
        return 'EUR';
      case RecipientType.speiClabeMxn:
      case RecipientType.speiSmsMxn:
      case RecipientType.speiCardMxn:
        return 'MXN';
      case RecipientType.sinpeIbanUsd:
        return 'USD';
      case RecipientType.sinpeIbanCrc:
      case RecipientType.sinpeMovilCrc:
        return 'CRC';
      case RecipientType.cbuCvuArgentina:
        return 'ARS';
      case RecipientType.pseColombia:
        return 'COP';
      case RecipientType.nequiColombia:
        return 'COP';
    }
  }

  static Set<RecipientType> typesForCurrency(String currencyCode) {
    return RecipientType.values
        .where((type) => type.currencyCode == currencyCode)
        .toSet();
  }
}
