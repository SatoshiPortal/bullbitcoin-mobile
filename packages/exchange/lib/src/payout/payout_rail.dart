import 'package:meta/meta.dart';

import '../domain/catalog/exchange_catalog.dart';
import '../domain/catalog/market.dart';
import '../domain/entities/sepa_payment_processor.dart';
import '../recipients/domain/entities/recipient.dart';
import '../recipients/domain/entities/recipient_details.dart';
import '../recipients/domain/entities/recipient_type.dart';
import 'payout_requirement.dart';

/// Why a recipient is paid: the rail decides per purpose which extra steps
/// a payout needs (composition §3.1).
enum PayoutPurpose { sell, pay, withdraw }

/// Whose account a recipient is. A flow's filter supplies it, and a new
/// recipient is always created with it (RCP-9).
enum RecipientOwnership {
  own,
  thirdParty;

  bool get isOwner => this == RecipientOwnership.own;
}

/// The kind of one account value, so the view has one label per kind
/// instead of one switch per recipient type (D6, D7).
enum AccountField {
  email,
  payee,
  accountNumber,
  bankAccount,
  iban,
  clabe,
  phone,
  card,
  cbuCvu,
}

/// One labelled value of a recipient's account, as the rail shows it.
@immutable
final class AccountRow {
  final AccountField field;
  final String value;

  const AccountRow(this.field, this.value);

  @override
  bool operator ==(Object other) =>
      other is AccountRow && other.field == field && other.value == value;

  @override
  int get hashCode => Object.hash(field, value);

  @override
  String toString() => 'AccountRow(${field.name})';
}

/// One way of paying fiat out of the exchange: a recipient type with its
/// market, account display and payout parameters (composition §3.1). Flows
/// and views ask the rail; they don't switch on the recipient type.
///
/// [D] is the recipient details the rail reads. A recipient is paired with
/// its rail by [RecipientRail.onRail], so the two always match.
@immutable
sealed class PayoutRail<D extends RecipientDetails> {
  const PayoutRail();

  /// The wire identity of the rail.
  RecipientType get type;

  /// The currency and jurisdiction the rail pays out in.
  Market get market;

  /// Whether the rail is offered only to accounts that are eligible for it
  /// (Confidential SEPA); a flow must ask for it explicitly.
  bool get needsEligibility => false;

  /// Whether a paid-out order on this rail has a receipt the user can open
  /// (SINPE Móvil), for every flow that pays such a recipient.
  bool get hasReceipt => false;

  /// The SEPA processor an order to this rail names; null for the rails that
  /// send none. The one mapping for every flow (D10).
  SepaPaymentProcessor? get paymentProcessor => null;

  /// The name the user knows the recipient by, or null when the recipient
  /// carries none.
  String? displayName(D details);

  /// The account values, in display order; the first one identifies the
  /// account when only one row fits.
  List<AccountRow> accountRows(D details);

  /// What must hold before an order for [purpose] can pay [details] on this
  /// rail, in the order the payout step asks for it. Empty for most rails.
  List<PayoutRequirement> requirements(D details, PayoutPurpose purpose) =>
      const [];

  /// The same account on the rail the user can fall back to when a
  /// requirement of this one can't be met (Confidential SEPA → SEPA), or
  /// null when there is none.
  RecipientDetails? fallback(D details) => null;

  @override
  String toString() => 'PayoutRail(${type.name})';
}

String? _text(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String? _firstText(Iterable<String?> candidates) {
  for (final candidate in candidates) {
    final text = _text(candidate);
    if (text != null) return text;
  }
  return null;
}

List<AccountRow> _rows(Iterable<(AccountField, String?)> rows) => [
  for (final (field, value) in rows) AccountRow(field, value?.trim() ?? ''),
];

final class InteracEmailRail extends PayoutRail<InteracEmailCadDetails> {
  const InteracEmailRail._();

  @override
  RecipientType get type => RecipientType.interacEmailCad;

  @override
  Market get market => ExchangeCatalog.cad;

  @override
  String? displayName(InteracEmailCadDetails details) =>
      _firstText([details.name, details.email]);

  @override
  List<AccountRow> accountRows(InteracEmailCadDetails details) =>
      _rows([(AccountField.email, details.email)]);

  /// Asked for every Interac payout, as BBX does: without a question and
  /// answer on the order or the recipient the payout never leaves NOT_READY.
  @override
  List<PayoutRequirement> requirements(
    InteracEmailCadDetails details,
    PayoutPurpose purpose,
  ) => [
    InteracSecurityRequired(
      question: details.securityQuestion,
      answer: details.securityAnswer,
    ),
  ];
}

final class BillPaymentRail extends PayoutRail<BillPaymentCadDetails> {
  const BillPaymentRail._();

  @override
  RecipientType get type => RecipientType.billPaymentCad;

  @override
  Market get market => ExchangeCatalog.cad;

  @override
  String? displayName(BillPaymentCadDetails details) =>
      _firstText([details.payeeName, details.label]);

  @override
  List<AccountRow> accountRows(BillPaymentCadDetails details) => _rows([
    (AccountField.accountNumber, details.payeeAccountNumber),
    (AccountField.payee, details.payeeName),
  ]);
}

final class BankTransferCadRail extends PayoutRail<BankTransferCadDetails> {
  const BankTransferCadRail._();

  @override
  RecipientType get type => RecipientType.bankTransferCad;

  @override
  Market get market => ExchangeCatalog.cad;

  @override
  String? displayName(BankTransferCadDetails details) =>
      _firstText([details.name, details.label]);

  @override
  List<AccountRow> accountRows(BankTransferCadDetails details) => _rows([
    (
      AccountField.bankAccount,
      '${details.institutionNumber}-${details.transitNumber}-'
          '${details.accountNumber}',
    ),
  ]);
}

String? _sepaName(SepaEurDetails details) {
  if (details.isCorporate) {
    final corporate = _text(details.corporateName);
    if (corporate != null) return corporate;
  }
  final first = _text(details.firstname);
  final last = _text(details.lastname);
  if (first != null && last != null) return '$first $last';
  return first ?? last ?? _text(details.label);
}

final class SepaRail extends PayoutRail<SepaEurDetails> {
  const SepaRail._();

  @override
  RecipientType get type => RecipientType.sepaEur;

  @override
  Market get market => ExchangeCatalog.eur;

  @override
  SepaPaymentProcessor get paymentProcessor => SepaPaymentProcessor.regular;

  @override
  String? displayName(SepaEurDetails details) => _sepaName(details);

  @override
  List<AccountRow> accountRows(SepaEurDetails details) =>
      _rows([(AccountField.iban, details.iban)]);
}

/// The same SEPA account, paid out through the user's virtual IBAN and the
/// recipient's virtual payee (both must be active first).
final class ConfidentialSepaRail extends PayoutRail<SepaEurDetails> {
  const ConfidentialSepaRail._();

  @override
  RecipientType get type => RecipientType.confidentialSepaEur;

  @override
  Market get market => ExchangeCatalog.eur;

  @override
  bool get needsEligibility => true;

  @override
  SepaPaymentProcessor get paymentProcessor =>
      SepaPaymentProcessor.confidential;

  @override
  String? displayName(SepaEurDetails details) => _sepaName(details);

  @override
  List<AccountRow> accountRows(SepaEurDetails details) =>
      _rows([(AccountField.iban, details.iban)]);

  @override
  List<PayoutRequirement> requirements(
    SepaEurDetails details,
    PayoutPurpose purpose,
  ) => [
    const VirtualIbanRequired(),
    VirtualPayeeRequired(alreadyActive: details.isVirtualPayeeActive),
  ];

  @override
  RecipientDetails fallback(SepaEurDetails details) => details.asRegular();
}

final class SpeiClabeRail extends PayoutRail<SpeiClabeMxnDetails> {
  const SpeiClabeRail._();

  @override
  RecipientType get type => RecipientType.speiClabeMxn;

  @override
  Market get market => ExchangeCatalog.mxn;

  @override
  String? displayName(SpeiClabeMxnDetails details) =>
      _firstText([details.name, details.label]);

  @override
  List<AccountRow> accountRows(SpeiClabeMxnDetails details) =>
      _rows([(AccountField.clabe, details.clabe)]);
}

final class SpeiSmsRail extends PayoutRail<SpeiSmsMxnDetails> {
  const SpeiSmsRail._();

  @override
  RecipientType get type => RecipientType.speiSmsMxn;

  @override
  Market get market => ExchangeCatalog.mxn;

  @override
  String? displayName(SpeiSmsMxnDetails details) =>
      _firstText([details.name, details.label]);

  @override
  List<AccountRow> accountRows(SpeiSmsMxnDetails details) =>
      _rows([(AccountField.phone, details.phone)]);
}

final class SpeiCardRail extends PayoutRail<SpeiCardMxnDetails> {
  const SpeiCardRail._();

  @override
  RecipientType get type => RecipientType.speiCardMxn;

  @override
  Market get market => ExchangeCatalog.mxn;

  @override
  String? displayName(SpeiCardMxnDetails details) =>
      _firstText([details.name, details.label]);

  @override
  List<AccountRow> accountRows(SpeiCardMxnDetails details) =>
      _rows([(AccountField.card, details.debitcard)]);
}

final class SinpeIbanUsdRail extends PayoutRail<SinpeIbanUsdDetails> {
  const SinpeIbanUsdRail._();

  @override
  RecipientType get type => RecipientType.sinpeIbanUsd;

  @override
  Market get market => ExchangeCatalog.usd;

  @override
  String? displayName(SinpeIbanUsdDetails details) =>
      _firstText([details.ownerName, details.label, details.iban]);

  @override
  List<AccountRow> accountRows(SinpeIbanUsdDetails details) =>
      _rows([(AccountField.iban, details.iban)]);
}

final class SinpeIbanCrcRail extends PayoutRail<SinpeIbanCrcDetails> {
  const SinpeIbanCrcRail._();

  @override
  RecipientType get type => RecipientType.sinpeIbanCrc;

  @override
  Market get market => ExchangeCatalog.crc;

  @override
  String? displayName(SinpeIbanCrcDetails details) =>
      _firstText([details.ownerName, details.label, details.iban]);

  @override
  List<AccountRow> accountRows(SinpeIbanCrcDetails details) =>
      _rows([(AccountField.iban, details.iban)]);
}

final class SinpeMovilRail extends PayoutRail<SinpeMovilCrcDetails> {
  const SinpeMovilRail._();

  @override
  RecipientType get type => RecipientType.sinpeMovilCrc;

  @override
  Market get market => ExchangeCatalog.crc;

  @override
  bool get hasReceipt => true;

  @override
  String? displayName(SinpeMovilCrcDetails details) =>
      _firstText([details.ownerName, details.label, details.phoneNumber]);

  @override
  List<AccountRow> accountRows(SinpeMovilCrcDetails details) =>
      _rows([(AccountField.phone, details.phoneNumber)]);
}

final class ArsBankTransferRail
    extends PayoutRail<BankAccountArgentinaDetails> {
  const ArsBankTransferRail._();

  @override
  RecipientType get type => RecipientType.bankAccountArgentina;

  @override
  Market get market => ExchangeCatalog.ars;

  @override
  String? displayName(BankAccountArgentinaDetails details) =>
      _firstText([details.name, details.label]);

  @override
  List<AccountRow> accountRows(BankAccountArgentinaDetails details) =>
      _rows([(AccountField.cbuCvu, details.claveUniform)]);
}

final class PseRail extends PayoutRail<PseColombiaDetails> {
  const PseRail._();

  @override
  RecipientType get type => RecipientType.pseColombia;

  @override
  Market get market => ExchangeCatalog.cop;

  @override
  String? displayName(PseColombiaDetails details) =>
      _firstText([details.name, details.label]);

  @override
  List<AccountRow> accountRows(PseColombiaDetails details) =>
      _rows([(AccountField.accountNumber, details.bankAccount)]);
}

final class NequiRail extends PayoutRail<NequiColombiaDetails> {
  const NequiRail._();

  @override
  RecipientType get type => RecipientType.nequiColombia;

  @override
  Market get market => ExchangeCatalog.cop;

  @override
  String? displayName(NequiColombiaDetails details) =>
      _firstText([details.name, details.label]);

  @override
  List<AccountRow> accountRows(NequiColombiaDetails details) =>
      _rows([(AccountField.phone, details.phoneNumber)]);
}

/// The 14 payout rails.
abstract final class PayoutRails {
  static const interacEmail = InteracEmailRail._();
  static const billPayment = BillPaymentRail._();
  static const bankTransferCad = BankTransferCadRail._();
  static const sepa = SepaRail._();
  static const confidentialSepa = ConfidentialSepaRail._();
  static const speiClabe = SpeiClabeRail._();
  static const speiSms = SpeiSmsRail._();
  static const speiCard = SpeiCardRail._();
  static const sinpeIbanUsd = SinpeIbanUsdRail._();
  static const sinpeIbanCrc = SinpeIbanCrcRail._();
  static const sinpeMovil = SinpeMovilRail._();
  static const arsBankTransfer = ArsBankTransferRail._();
  static const pse = PseRail._();
  static const nequi = NequiRail._();

  /// Every rail, in the order the pickers show them.
  static const List<PayoutRail> all = [
    interacEmail,
    billPayment,
    bankTransferCad,
    sepa,
    confidentialSepa,
    speiClabe,
    speiSms,
    speiCard,
    sinpeIbanUsd,
    sinpeIbanCrc,
    sinpeMovil,
    arsBankTransfer,
    pse,
    nequi,
  ];

  /// The rails offered to every account: all but those that need
  /// eligibility.
  static List<PayoutRail> get standard => [
    for (final rail in all)
      if (!rail.needsEligibility) rail,
  ];

  /// The rails of [market], eligibility-only ones included.
  static List<PayoutRail> ofMarket(Market market) => [
    for (final rail in all)
      if (rail.market == market) rail,
  ];

  static PayoutRail of(RecipientType type) => switch (type) {
    RecipientType.interacEmailCad => interacEmail,
    RecipientType.billPaymentCad => billPayment,
    RecipientType.bankTransferCad => bankTransferCad,
    RecipientType.sepaEur => sepa,
    RecipientType.confidentialSepaEur => confidentialSepa,
    RecipientType.speiClabeMxn => speiClabe,
    RecipientType.speiSmsMxn => speiSms,
    RecipientType.speiCardMxn => speiCard,
    RecipientType.sinpeIbanUsd => sinpeIbanUsd,
    RecipientType.sinpeIbanCrc => sinpeIbanCrc,
    RecipientType.sinpeMovilCrc => sinpeMovil,
    RecipientType.bankAccountArgentina => arsBankTransfer,
    RecipientType.pseColombia => pse,
    RecipientType.nequiColombia => nequi,
  };
}

/// A recipient's details together with the rail that reads them. Only
/// [RecipientRail.onRail] makes one, so the pair always matches.
@immutable
final class DetailsOnRail<D extends RecipientDetails> {
  final PayoutRail<D> rail;
  final D details;

  const DetailsOnRail._(this.rail, this.details);

  String? get displayName => rail.displayName(details);

  List<AccountRow> get accountRows => rail.accountRows(details);

  List<PayoutRequirement> requirements(PayoutPurpose purpose) =>
      rail.requirements(details, purpose);

  RecipientDetails? get fallback => rail.fallback(details);
}

DetailsOnRail<D> _on<D extends RecipientDetails>(
  PayoutRail<D> rail,
  D details,
) => DetailsOnRail._(rail, details);

extension RecipientDetailsRail on RecipientDetails {
  /// These details paired with their rail.
  DetailsOnRail<RecipientDetails> get onRail => switch (this) {
    final InteracEmailCadDetails d => _on(PayoutRails.interacEmail, d),
    final BillPaymentCadDetails d => _on(PayoutRails.billPayment, d),
    final BankTransferCadDetails d => _on(PayoutRails.bankTransferCad, d),
    final SepaEurDetails d when d.isConfidential => _on(
      PayoutRails.confidentialSepa,
      d,
    ),
    final SepaEurDetails d => _on(PayoutRails.sepa, d),
    final SpeiClabeMxnDetails d => _on(PayoutRails.speiClabe, d),
    final SpeiSmsMxnDetails d => _on(PayoutRails.speiSms, d),
    final SpeiCardMxnDetails d => _on(PayoutRails.speiCard, d),
    final SinpeIbanUsdDetails d => _on(PayoutRails.sinpeIbanUsd, d),
    final SinpeIbanCrcDetails d => _on(PayoutRails.sinpeIbanCrc, d),
    final SinpeMovilCrcDetails d => _on(PayoutRails.sinpeMovil, d),
    final BankAccountArgentinaDetails d => _on(PayoutRails.arsBankTransfer, d),
    final PseColombiaDetails d => _on(PayoutRails.pse, d),
    final NequiColombiaDetails d => _on(PayoutRails.nequi, d),
  };

  PayoutRail get rail => onRail.rail;
}

extension RecipientRail on Recipient {
  /// The recipient's details paired with their rail.
  DetailsOnRail<RecipientDetails> get onRail => details.onRail;

  PayoutRail get rail => details.rail;
}
