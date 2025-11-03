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
  // MEXICO
  speiClabeMxn('SPEI_CLABE_MXN'),
  speiSmsMxn('SPEI_SMS_MXN'),
  speiCardMxn('SPEI_CARD_MXN'),
  // COSTA RICA
  sinpeIbanUsd('SINPE_IBAN_USD'),
  sinpeIbanCrc('SINPE_IBAN_CRC'),
  sinpeMovilCrc('SINPE_MOVIL_CRC');

  final String value;
  const RecipientType(this.value);

  static RecipientType fromValue(String value) {
    return RecipientType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw Exception('Unknown RecipientType: $value'),
    );
  }

  String get countryCode {
    switch (this) {
      case RecipientType.interacEmailCad:
      case RecipientType.billPaymentCad:
      case RecipientType.bankTransferCad:
        return 'CA';
      case RecipientType.sepaEur:
        return 'EU';
      case RecipientType.speiClabeMxn:
      case RecipientType.speiSmsMxn:
      case RecipientType.speiCardMxn:
        return 'MX';
      case RecipientType.sinpeIbanUsd:
      case RecipientType.sinpeIbanCrc:
      case RecipientType.sinpeMovilCrc:
        return 'CR';
    }
  }

  String get currencyCode {
    switch (this) {
      case RecipientType.interacEmailCad:
      case RecipientType.billPaymentCad:
      case RecipientType.bankTransferCad:
        return 'CAD';
      case RecipientType.sepaEur:
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
    }
  }
}
