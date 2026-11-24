import 'package:meta/meta.dart';

import '../domain/catalog/jurisdiction.dart';
import 'funding_instructions.dart';

/// One way to put fiat on the exchange account (composition §3.2). The rail
/// owns its jurisdiction, the consent it needs, the steps before its
/// instructions and which instruction fields it shows. Flows never switch on
/// a rail; the UI has one switch for its copy.
@immutable
sealed class FundingRail {
  const FundingRail();

  Jurisdiction get jurisdiction;

  /// Every rail asks for the scam-warning consent before its instructions,
  /// Confidential SEPA included (FUND-4).
  bool get requiresConsent => true;

  /// What the user does between the consent and the instructions.
  FundingPreStep get preStep;

  /// A stable name for logs and tests.
  String get name;

  @override
  String toString() => 'FundingRail($name)';
}

/// What a rail needs between the consent and its instructions.
enum FundingPreStep {
  /// The instructions are fetched at once.
  none,

  /// Pick the paying bank and enter the amount (COP).
  institutionAndAmount,

  /// Create or activate the user's virtual IBAN; its details are the
  /// instructions (Confidential SEPA).
  virtualIban,
}

/// A rail whose instructions are the answer to the user's payment processor
/// code. Only the [fields] it shows are required from the answer, so a field
/// the rail never shows can't break it (03 §12.4).
sealed class ProcessorCodeRail extends FundingRail {
  const ProcessorCodeRail();

  String get paymentProcessorCode;

  /// The fields the instructions show, in order.
  List<InstructionField> get fields;

  @override
  FundingPreStep get preStep => FundingPreStep.none;

  /// The instructions from one row per field of [fields], in order.
  FundingInstructions present(List<InstructionRow> rows) =>
      FundingInstructionRows(rows);
}

final class EmailETransferRail extends ProcessorCodeRail {
  const EmailETransferRail();

  @override
  String get name => 'emailETransfer';

  @override
  Jurisdiction get jurisdiction => Jurisdiction.canada;

  @override
  String get paymentProcessorCode => 'IN_CAD_EMAIL_TRANSFER_APL';

  /// The secret answer is the account's user number, from the loaded
  /// context (03 §12.3).
  @override
  List<InstructionField> get fields => const [
    InstructionField.beneficiaryName,
    InstructionField.beneficiaryEmail,
    InstructionField.secretQuestion,
    InstructionField.secretAnswer,
  ];
}

final class BankWireRail extends ProcessorCodeRail {
  const BankWireRail();

  @override
  String get name => 'bankWire';

  @override
  Jurisdiction get jurisdiction => Jurisdiction.canada;

  @override
  String get paymentProcessorCode => 'IN_CAD_WIRE_TRANSFER_SCU';

  @override
  List<InstructionField> get fields => const [
    InstructionField.beneficiaryName,
    InstructionField.transferCode,
    InstructionField.bankAccountDetails,
    InstructionField.swift,
    InstructionField.institutionNumber,
    InstructionField.transitNumber,
    InstructionField.routingNumber,
    InstructionField.beneficiaryAddress,
    InstructionField.bankName,
    InstructionField.bankAddress,
  ];
}

final class OnlineBillPaymentRail extends ProcessorCodeRail {
  const OnlineBillPaymentRail();

  @override
  String get name => 'onlineBillPayment';

  @override
  Jurisdiction get jurisdiction => Jurisdiction.canada;

  @override
  String get paymentProcessorCode => 'IN_CAD_BILL_PAYMENT_APL';

  @override
  List<InstructionField> get fields => const [
    InstructionField.billerName,
    InstructionField.transferCode,
  ];
}

/// Canada Post shows its code as a QR code.
final class CanadaPostRail extends ProcessorCodeRail {
  const CanadaPostRail();

  @override
  String get name => 'canadaPost';

  @override
  Jurisdiction get jurisdiction => Jurisdiction.canada;

  @override
  String get paymentProcessorCode => 'IN_CAD_LOADHUB';

  @override
  List<InstructionField> get fields => const [InstructionField.transferCode];

  @override
  FundingInstructions present(List<InstructionRow> rows) =>
      FundingInstructionQr(rows.single.value);
}

final class ConfidentialSepaRail extends FundingRail {
  const ConfidentialSepaRail();

  @override
  String get name => 'confidentialSepa';

  @override
  Jurisdiction get jurisdiction => Jurisdiction.europe;

  @override
  FundingPreStep get preStep => FundingPreStep.virtualIban;
}

final class InstantSepaRail extends ProcessorCodeRail {
  const InstantSepaRail();

  @override
  String get name => 'instantSepa';

  @override
  Jurisdiction get jurisdiction => Jurisdiction.europe;

  @override
  String get paymentProcessorCode => 'IN_EUR_CJ_IBAN';

  @override
  List<InstructionField> get fields => const [
    InstructionField.iban,
    InstructionField.beneficiaryName,
    InstructionField.transferCode,
    InstructionField.bankAccountCountry,
    InstructionField.bic,
    InstructionField.beneficiaryAddress,
  ];
}

final class RegularSepaRail extends ProcessorCodeRail {
  const RegularSepaRail();

  @override
  String get name => 'regularSepa';

  @override
  Jurisdiction get jurisdiction => Jurisdiction.europe;

  @override
  String get paymentProcessorCode => 'IN_EUR_SEPA_DELUBAC';

  @override
  List<InstructionField> get fields => const [
    InstructionField.iban,
    InstructionField.beneficiaryName,
    InstructionField.transferCode,
    InstructionField.bankCountry,
    InstructionField.bic,
    InstructionField.beneficiaryAddress,
  ];
}

final class SpeiRail extends ProcessorCodeRail {
  const SpeiRail();

  @override
  String get name => 'spei';

  @override
  Jurisdiction get jurisdiction => Jurisdiction.mexico;

  @override
  String get paymentProcessorCode => 'IN_MXN_BITSO_CLABE';

  @override
  List<InstructionField> get fields => const [
    InstructionField.clabe,
    InstructionField.beneficiaryName,
    InstructionField.bankName,
    InstructionField.transferCode,
  ];
}

final class SinpeMovilRail extends ProcessorCodeRail {
  const SinpeMovilRail();

  @override
  String get name => 'sinpeMovil';

  @override
  Jurisdiction get jurisdiction => Jurisdiction.costaRica;

  @override
  String get paymentProcessorCode => 'IN_CRC_RDV_SINPE';

  @override
  List<InstructionField> get fields => const [
    InstructionField.phoneNumber,
    InstructionField.beneficiaryName,
  ];
}

final class CostaRicaIbanCrcRail extends ProcessorCodeRail {
  const CostaRicaIbanCrcRail();

  @override
  String get name => 'costaRicaIbanCrc';

  @override
  Jurisdiction get jurisdiction => Jurisdiction.costaRica;

  @override
  String get paymentProcessorCode => 'IN_CRC_RDV_IBAN';

  @override
  List<InstructionField> get fields => _costaRicaIbanFields;
}

/// The only USD rail: USD is a Costa Rica market (C1).
final class CostaRicaIbanUsdRail extends ProcessorCodeRail {
  const CostaRicaIbanUsdRail();

  @override
  String get name => 'costaRicaIbanUsd';

  @override
  Jurisdiction get jurisdiction => Jurisdiction.costaRica;

  @override
  String get paymentProcessorCode => 'IN_USD_RDV_IBAN';

  @override
  List<InstructionField> get fields => _costaRicaIbanFields;
}

const _costaRicaIbanFields = [
  InstructionField.iban,
  InstructionField.transferCode,
  InstructionField.beneficiaryName,
  InstructionField.cedulaJuridica,
];

final class ArsBankTransferRail extends ProcessorCodeRail {
  const ArsBankTransferRail();

  @override
  String get name => 'arsBankTransfer';

  @override
  Jurisdiction get jurisdiction => Jurisdiction.argentina;

  @override
  String get paymentProcessorCode => 'IN_ARS_BITSO';

  @override
  List<InstructionField> get fields => const [
    InstructionField.beneficiaryName,
    InstructionField.cvu,
  ];
}

/// COP: the user picks the paying bank and the amount; the instructions are
/// a payment link.
final class CopBankTransferRail extends FundingRail {
  const CopBankTransferRail();

  @override
  String get name => 'copBankTransfer';

  @override
  Jurisdiction get jurisdiction => Jurisdiction.colombia;

  @override
  FundingPreStep get preStep => FundingPreStep.institutionAndAmount;
}

/// Every funding rail, in the order the fund screen lists them.
abstract final class FundingRails {
  static const List<FundingRail> all = [
    EmailETransferRail(),
    BankWireRail(),
    OnlineBillPaymentRail(),
    CanadaPostRail(),
    ConfidentialSepaRail(),
    InstantSepaRail(),
    RegularSepaRail(),
    SpeiRail(),
    SinpeMovilRail(),
    CostaRicaIbanCrcRail(),
    CostaRicaIbanUsdRail(),
    ArsBankTransferRail(),
    CopBankTransferRail(),
  ];

  /// The rails of [jurisdiction], in display order.
  static List<FundingRail> of(Jurisdiction jurisdiction) => [
    for (final rail in all)
      if (rail.jurisdiction == jurisdiction) rail,
  ];
}
