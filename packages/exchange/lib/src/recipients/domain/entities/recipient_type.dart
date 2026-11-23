import '../../../domain/catalog/jurisdiction.dart';
import '../../../domain/entities/order.dart';

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
  confidentialSepaEur('SEPA_EUR'),
  // MEXICO
  speiClabeMxn('SPEI_CLABE_MXN'),
  speiSmsMxn('SPEI_SMS_MXN'),
  speiCardMxn('SPEI_CARD_MXN'),
  // COSTA RICA
  sinpeIbanUsd('SINPE_IBAN_USD'),
  sinpeIbanCrc('SINPE_IBAN_CRC'),
  sinpeMovilCrc('SINPE_MOVIL_CRC'),
  // ARGENTINA
  bankAccountArgentina('BANK_TRANSFER_ARS'),
  // Colombia
  pseColombia('PSE_COLOMBIA_COP'),
  nequiColombia('NEQUI_COLOMBIA_COP');

  final String value;
  const RecipientType(this.value);

  static RecipientType fromValue(String value) {
    return RecipientType.values.firstWhere(
      (e) => e.value == value && e != RecipientType.confidentialSepaEur,
      orElse: () => throw Exception('Unknown RecipientType: $value'),
    );
  }

  Jurisdiction get jurisdiction => switch (this) {
    RecipientType.interacEmailCad ||
    RecipientType.billPaymentCad ||
    RecipientType.bankTransferCad => Jurisdiction.canada,
    RecipientType.sepaEur ||
    RecipientType.confidentialSepaEur => Jurisdiction.europe,
    RecipientType.speiClabeMxn ||
    RecipientType.speiSmsMxn ||
    RecipientType.speiCardMxn => Jurisdiction.mexico,
    RecipientType.sinpeIbanUsd ||
    RecipientType.sinpeIbanCrc ||
    RecipientType.sinpeMovilCrc => Jurisdiction.costaRica,
    RecipientType.bankAccountArgentina => Jurisdiction.argentina,
    RecipientType.pseColombia ||
    RecipientType.nequiColombia => Jurisdiction.colombia,
  };

  FiatCurrency get currency => switch (this) {
    RecipientType.interacEmailCad ||
    RecipientType.billPaymentCad ||
    RecipientType.bankTransferCad => FiatCurrency.cad,
    RecipientType.sepaEur ||
    RecipientType.confidentialSepaEur => FiatCurrency.eur,
    RecipientType.speiClabeMxn ||
    RecipientType.speiSmsMxn ||
    RecipientType.speiCardMxn => FiatCurrency.mxn,
    RecipientType.sinpeIbanUsd => FiatCurrency.usd,
    RecipientType.sinpeIbanCrc ||
    RecipientType.sinpeMovilCrc => FiatCurrency.crc,
    RecipientType.bankAccountArgentina => FiatCurrency.ars,
    RecipientType.pseColombia ||
    RecipientType.nequiColombia => FiatCurrency.cop,
  };

  String get currencyCode => currency.code;

  /// Confidential SEPA depends on the user's eligibility, so a flow must
  /// request it explicitly.
  static List<RecipientType> get standardTypes => RecipientType.values
      .where((type) => type != RecipientType.confidentialSepaEur)
      .toList();

  static Set<RecipientType> typesForCurrency(String currencyCode) {
    return standardTypes
        .where((type) => type.currencyCode == currencyCode)
        .toSet();
  }
}
