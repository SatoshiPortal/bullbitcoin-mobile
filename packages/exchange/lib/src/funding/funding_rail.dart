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
sealed class ProcessorCodeFundingRail extends FundingRail {
  const ProcessorCodeFundingRail();

  String get paymentProcessorCode;

  /// The fields the instructions show, in order.
  List<InstructionField> get fields;

  @override
  FundingPreStep get preStep => FundingPreStep.none;

  /// The instructions from one row per field of [fields], in order.
  FundingInstructions present(List<InstructionRow> rows) =>
      FundingInstructionRows(rows);
}

final class EmailETransferFundingRail extends ProcessorCodeFundingRail {
  const EmailETransferFundingRail();

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

final class BankWireFundingRail extends ProcessorCodeFundingRail {
  const BankWireFundingRail();

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

final class OnlineBillPaymentFundingRail extends ProcessorCodeFundingRail {
  const OnlineBillPaymentFundingRail();

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
final class CanadaPostFundingRail extends ProcessorCodeFundingRail {
  const CanadaPostFundingRail();

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

final class ConfidentialSepaFundingRail extends FundingRail {
  const ConfidentialSepaFundingRail();

  @override
  String get name => 'confidentialSepa';

  @override
  Jurisdiction get jurisdiction => Jurisdiction.europe;

  @override
  FundingPreStep get preStep => FundingPreStep.virtualIban;
}

final class InstantSepaFundingRail extends ProcessorCodeFundingRail {
  const InstantSepaFundingRail();

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

final class RegularSepaFundingRail extends ProcessorCodeFundingRail {
  const RegularSepaFundingRail();

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

final class SpeiFundingRail extends ProcessorCodeFundingRail {
  const SpeiFundingRail();

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

final class SinpeMovilFundingRail extends ProcessorCodeFundingRail {
  const SinpeMovilFundingRail();

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

final class CostaRicaIbanCrcFundingRail extends ProcessorCodeFundingRail {
  const CostaRicaIbanCrcFundingRail();

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
final class CostaRicaIbanUsdFundingRail extends ProcessorCodeFundingRail {
  const CostaRicaIbanUsdFundingRail();

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

final class ArsBankTransferFundingRail extends ProcessorCodeFundingRail {
  const ArsBankTransferFundingRail();

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
final class CopBankTransferFundingRail extends FundingRail {
  const CopBankTransferFundingRail();

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
    EmailETransferFundingRail(),
    BankWireFundingRail(),
    OnlineBillPaymentFundingRail(),
    CanadaPostFundingRail(),
    ConfidentialSepaFundingRail(),
    InstantSepaFundingRail(),
    RegularSepaFundingRail(),
    SpeiFundingRail(),
    SinpeMovilFundingRail(),
    CostaRicaIbanCrcFundingRail(),
    CostaRicaIbanUsdFundingRail(),
    ArsBankTransferFundingRail(),
    CopBankTransferFundingRail(),
  ];

  /// The rails of [jurisdiction], in display order.
  static List<FundingRail> of(Jurisdiction jurisdiction) => [
    for (final rail in all)
      if (rail.jurisdiction == jurisdiction) rail,
  ];
}
