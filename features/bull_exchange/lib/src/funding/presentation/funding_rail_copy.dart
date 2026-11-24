import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:exchange/funding.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// A piece of copy; [bold] parts are emphasised.
@immutable
final class CopyPart {
  final String text;
  final bool bold;

  const CopyPart(this.text, {this.bold = false});
}

/// How one instruction field reads on a rail.
@immutable
final class FieldCopy {
  final String label;
  final String? help;

  /// An info card shown right below the field.
  final String? notice;

  const FieldCopy(this.label, {this.help, this.notice});
}

@immutable
final class FundingTileCopy {
  final String title;
  final String subtitle;

  const FundingTileCopy(this.title, this.subtitle);
}

/// Everything a rail's instructions screen says around the server's values.
@immutable
final class FundingInstructionsCopy {
  final String title;

  /// Paragraphs, each a run of parts.
  final List<List<CopyPart>> intro;

  /// Numbered steps (Canada Post).
  final List<String> steps;

  /// An info card above the values.
  final String? notice;

  /// A warning box above the values (SINPE: no bitcoin in the description).
  final List<CopyPart>? warning;
  final Map<InstructionField, FieldCopy> fields;

  const FundingInstructionsCopy({
    required this.title,
    this.intro = const [],
    this.steps = const [],
    this.notice,
    this.warning,
    this.fields = const {},
  });
}

/// The one place a funding rail turns into words: its tile and its
/// instructions copy. One exhaustive switch over the rails.
extension FundingRailCopy on FundingRail {
  FundingTileCopy tile(BuildContext context) {
    final l = context.loc;
    return switch (this) {
      EmailETransferFundingRail() => FundingTileCopy(
        l.fundExchangeMethodEmailETransfer,
        l.fundExchangeMethodEmailETransferSubtitle,
      ),
      BankWireFundingRail() => FundingTileCopy(
        l.fundExchangeMethodBankTransferWire,
        l.fundExchangeMethodBankTransferWireSubtitle,
      ),
      OnlineBillPaymentFundingRail() => FundingTileCopy(
        l.fundExchangeMethodOnlineBillPayment,
        l.fundExchangeMethodOnlineBillPaymentSubtitle,
      ),
      CanadaPostFundingRail() => FundingTileCopy(
        l.fundExchangeMethodCanadaPost,
        l.fundExchangeMethodCanadaPostSubtitle,
      ),
      ConfidentialSepaFundingRail() => FundingTileCopy(
        l.fundExchangeMethodConfidentialSepa,
        l.fundExchangeMethodConfidentialSepaSubtitle,
      ),
      InstantSepaFundingRail() => FundingTileCopy(
        l.fundExchangeMethodInstantSepa,
        l.fundExchangeMethodInstantSepaSubtitle,
      ),
      RegularSepaFundingRail() => FundingTileCopy(
        l.fundExchangeMethodRegularSepa,
        l.fundExchangeMethodRegularSepaSubtitle,
      ),
      SpeiFundingRail() => FundingTileCopy(
        l.fundExchangeSpeiTransfer,
        l.fundExchangeSpeiSubtitle,
      ),
      SinpeMovilFundingRail() => FundingTileCopy(
        l.fundExchangeCostaRicaMethodSinpeTitle,
        l.fundExchangeCostaRicaMethodSinpeSubtitle,
      ),
      CostaRicaIbanCrcFundingRail() => FundingTileCopy(
        l.fundExchangeCostaRicaMethodIbanCrcTitle,
        l.fundExchangeCostaRicaMethodIbanCrcSubtitle,
      ),
      CostaRicaIbanUsdFundingRail() => FundingTileCopy(
        l.fundExchangeCostaRicaMethodIbanUsdTitle,
        l.fundExchangeCostaRicaMethodIbanUsdSubtitle,
      ),
      ArsBankTransferFundingRail() ||
      CopBankTransferFundingRail() => FundingTileCopy(
        l.fundExchangeBankTransfer,
        l.fundExchangeBankTransferSubtitle,
      ),
    };
  }

  FundingInstructionsCopy instructionsCopy(BuildContext context) {
    final l = context.loc;
    final sepaIntro = [
      [
        CopyPart(l.fundExchangeSepaDescription),
        CopyPart(l.fundExchangeSepaDescriptionExactly, bold: true),
      ],
    ];
    return switch (this) {
      EmailETransferFundingRail() => FundingInstructionsCopy(
        title: l.fundExchangeETransferTitle,
        intro: [
          [CopyPart(l.fundExchangeETransferDescription)],
        ],
        fields: {
          InstructionField.beneficiaryName: FieldCopy(
            l.fundExchangeETransferLabelBeneficiaryName,
          ),
          InstructionField.beneficiaryEmail: FieldCopy(
            l.fundExchangeETransferLabelEmail,
          ),
          InstructionField.secretQuestion: FieldCopy(
            l.fundExchangeETransferLabelSecretQuestion,
          ),
          InstructionField.secretAnswer: FieldCopy(
            l.fundExchangeETransferLabelSecretAnswer,
          ),
        },
      ),
      BankWireFundingRail() => FundingInstructionsCopy(
        title: l.fundExchangeBankTransferWireTitle,
        intro: [
          [CopyPart(l.fundExchangeBankTransferWireDescription)],
          [CopyPart(l.fundExchangeBankTransferWireTimeframe)],
        ],
        fields: {
          InstructionField.beneficiaryName: FieldCopy(
            l.fundExchangeLabelBeneficiaryName,
            help: l.fundExchangeHelpBeneficiaryName,
          ),
          InstructionField.transferCode: FieldCopy(
            l.fundExchangeLabelTransferCode,
            help: l.fundExchangeHelpTransferCode,
            notice: l.fundExchangeInfoTransferCode,
          ),
          InstructionField.bankAccountDetails: FieldCopy(
            l.fundExchangeLabelBankAccountDetails,
          ),
          InstructionField.swift: FieldCopy(l.fundExchangeLabelSwiftCode),
          InstructionField.institutionNumber: FieldCopy(
            l.fundExchangeLabelInstitutionNumber,
          ),
          InstructionField.transitNumber: FieldCopy(
            l.fundExchangeLabelTransitNumber,
          ),
          InstructionField.routingNumber: FieldCopy(
            l.fundExchangeLabelRoutingNumber,
          ),
          InstructionField.beneficiaryAddress: FieldCopy(
            l.fundExchangeLabelBeneficiaryAddress,
          ),
          InstructionField.bankName: FieldCopy(l.fundExchangeLabelBankName),
          InstructionField.bankAddress: FieldCopy(
            l.fundExchangeLabelBankAddress,
          ),
        },
      ),
      OnlineBillPaymentFundingRail() => FundingInstructionsCopy(
        title: l.fundExchangeOnlineBillPaymentTitle,
        intro: [
          [CopyPart(l.fundExchangeOnlineBillPaymentDescription)],
        ],
        fields: {
          InstructionField.billerName: FieldCopy(
            l.fundExchangeOnlineBillPaymentLabelBillerName,
            help: l.fundExchangeOnlineBillPaymentHelpBillerName,
          ),
          InstructionField.transferCode: FieldCopy(
            l.fundExchangeOnlineBillPaymentLabelAccountNumber,
            help: l.fundExchangeOnlineBillPaymentHelpAccountNumber,
          ),
        },
      ),
      CanadaPostFundingRail() => FundingInstructionsCopy(
        title: l.fundExchangeCanadaPostTitle,
        steps: [
          l.fundExchangeCanadaPostStep1,
          l.fundExchangeCanadaPostStep2,
          l.fundExchangeCanadaPostStep3,
          l.fundExchangeCanadaPostStep4,
          l.fundExchangeCanadaPostStep5,
          l.fundExchangeCanadaPostStep6,
          l.fundExchangeCanadaPostStep7,
        ],
        fields: {
          InstructionField.transferCode: FieldCopy(
            l.fundExchangeCanadaPostQrCodeLabel,
          ),
        },
      ),
      ConfidentialSepaFundingRail() => FundingInstructionsCopy(
        title: l.fundExchangeMethodConfidentialSepa,
      ),
      InstantSepaFundingRail() => FundingInstructionsCopy(
        title: l.fundExchangeSepaTitle,
        intro: sepaIntro,
        notice: l.fundExchangeInstantSepaInfo,
        fields: {
          InstructionField.iban: FieldCopy(l.fundExchangeLabelIban),
          InstructionField.beneficiaryName: FieldCopy(
            l.fundExchangeLabelBeneficiaryName,
            notice: l.fundExchangeInfoBeneficiaryNameLeonod,
          ),
          InstructionField.transferCode: FieldCopy(
            l.fundExchangeLabelTransferCode,
            notice: l.fundExchangeInfoPaymentDescription,
          ),
          InstructionField.bankAccountCountry: FieldCopy(
            l.fundExchangeLabelBankAccountCountry,
            notice: l.fundExchangeInfoBankCountryUk,
          ),
          InstructionField.bic: FieldCopy(l.fundExchangeLabelBicCode),
          InstructionField.beneficiaryAddress: FieldCopy(
            l.fundExchangeLabelBeneficiaryAddress,
            help: l.fundExchangeHelpBeneficiaryAddress,
          ),
        },
      ),
      RegularSepaFundingRail() => FundingInstructionsCopy(
        title: l.fundExchangeSepaTitle,
        intro: sepaIntro,
        notice: l.fundExchangeRegularSepaInfo,
        fields: {
          InstructionField.iban: FieldCopy(l.fundExchangeLabelIban),
          InstructionField.beneficiaryName: FieldCopy(
            l.fundExchangeLabelRecipientName,
          ),
          InstructionField.transferCode: FieldCopy(
            l.fundExchangeLabelTransferCode,
            notice: l.fundExchangeInfoPaymentDescription,
          ),
          InstructionField.bankCountry: FieldCopy(
            l.fundExchangeLabelBankCountry,
          ),
          InstructionField.bic: FieldCopy(l.fundExchangeLabelBicCode),
          InstructionField.beneficiaryAddress: FieldCopy(
            l.fundExchangeLabelRecipientAddress,
          ),
        },
      ),
      SpeiFundingRail() => FundingInstructionsCopy(
        title: l.fundExchangeSpeiTitle,
        intro: [
          [CopyPart(l.fundExchangeSpeiDescription)],
        ],
        notice: l.fundExchangeSpeiInfo,
        fields: {
          InstructionField.clabe: FieldCopy(l.fundExchangeLabelClabe),
          InstructionField.beneficiaryName: FieldCopy(
            l.fundExchangeLabelBeneficiaryName,
          ),
          InstructionField.bankName: FieldCopy(l.fundExchangeLabelBankName),
          InstructionField.transferCode: FieldCopy(l.fundExchangeLabelMemo),
        },
      ),
      SinpeMovilFundingRail() => FundingInstructionsCopy(
        title: l.fundExchangeSinpeTitle,
        intro: [
          [
            CopyPart(l.fundExchangeSinpeDescription),
            CopyPart(l.fundExchangeSinpeDescriptionBold, bold: true),
          ],
          [CopyPart(l.fundExchangeSinpeAddedToBalance)],
        ],
        warning: [
          CopyPart(l.fundExchangeSinpeWarningNoBitcoin, bold: true),
          CopyPart(l.fundExchangeSinpeWarningNoBitcoinDescription),
        ],
        fields: {
          InstructionField.phoneNumber: FieldCopy(
            l.fundExchangeSinpeLabelPhone,
          ),
          InstructionField.beneficiaryName: FieldCopy(
            l.fundExchangeSinpeLabelRecipientName,
          ),
        },
      ),
      CostaRicaIbanCrcFundingRail() => FundingInstructionsCopy(
        title: l.fundExchangeCrIbanCrcTitle,
        intro: [
          [
            CopyPart(l.fundExchangeCrIbanCrcDescription),
            CopyPart(l.fundExchangeCrIbanCrcDescriptionBold, bold: true),
            CopyPart(l.fundExchangeCrIbanCrcDescriptionEnd),
          ],
        ],
        fields: {
          InstructionField.iban: FieldCopy(l.fundExchangeCrIbanCrcLabelIban),
          InstructionField.transferCode: FieldCopy(
            l.fundExchangeCrIbanCrcLabelPaymentDescription,
            help: l.fundExchangeCrIbanCrcPaymentDescriptionHelp,
            notice: l.fundExchangeCrIbanCrcTransferCodeWarning,
          ),
          InstructionField.beneficiaryName: FieldCopy(
            l.fundExchangeCrIbanCrcLabelRecipientName,
            help: l.fundExchangeCrIbanCrcRecipientNameHelp,
          ),
          InstructionField.cedulaJuridica: FieldCopy(
            l.fundExchangeCrIbanCrcLabelCedulaJuridica,
          ),
        },
      ),
      CostaRicaIbanUsdFundingRail() => FundingInstructionsCopy(
        title: l.fundExchangeCrIbanUsdTitle,
        intro: [
          [
            CopyPart(l.fundExchangeCrIbanUsdDescription),
            CopyPart(l.fundExchangeCrIbanUsdDescriptionBold, bold: true),
            CopyPart(l.fundExchangeCrIbanUsdDescriptionEnd),
          ],
        ],
        fields: {
          InstructionField.iban: FieldCopy(l.fundExchangeCrIbanUsdLabelIban),
          InstructionField.transferCode: FieldCopy(
            l.fundExchangeCrIbanUsdLabelPaymentDescription,
            help: l.fundExchangeCrIbanUsdPaymentDescriptionHelp,
            notice: l.fundExchangeCrIbanUsdTransferCodeWarning,
          ),
          InstructionField.beneficiaryName: FieldCopy(
            l.fundExchangeCrIbanUsdLabelRecipientName,
            help: l.fundExchangeCrIbanUsdRecipientNameHelp,
          ),
          InstructionField.cedulaJuridica: FieldCopy(
            l.fundExchangeCrIbanUsdLabelCedulaJuridica,
          ),
        },
      ),
      ArsBankTransferFundingRail() => FundingInstructionsCopy(
        title: l.fundExchangeArsBankTransferTitle,
        intro: [
          [CopyPart(l.fundExchangeArsBankTransferDescription)],
        ],
        fields: {
          InstructionField.beneficiaryName: FieldCopy(
            l.fundExchangeLabelRecipientNameArs,
          ),
          InstructionField.cvu: FieldCopy(l.fundExchangeLabelCvu),
        },
      ),
      CopBankTransferFundingRail() => FundingInstructionsCopy(
        title: l.fundExchangeBankTransfer,
        intro: [
          [CopyPart(l.fundExchangeCopRedirectMessage, bold: true)],
        ],
      ),
    };
  }
}
