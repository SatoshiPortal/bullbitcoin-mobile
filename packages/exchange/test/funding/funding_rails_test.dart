import 'package:exchange/exchange.dart';
import 'package:exchange/funding.dart';
import 'package:test/test.dart';

void main() {
  test('every jurisdiction has rails, and every rail is listed once', () {
    for (final jurisdiction in Jurisdiction.values) {
      expect(
        FundingRails.of(jurisdiction),
        isNotEmpty,
        reason: '$jurisdiction',
      );
    }
    final listed = [
      for (final jurisdiction in Jurisdiction.values)
        ...FundingRails.of(jurisdiction),
    ];
    expect(listed.toSet(), FundingRails.all.toSet());
    expect(listed, hasLength(13));
    expect({for (final rail in listed) rail.name}, hasLength(13));
  });

  test('each jurisdiction lists the methods it had, in the same order', () {
    expect(FundingRails.of(Jurisdiction.canada), const [
      EmailETransferRail(),
      BankWireRail(),
      OnlineBillPaymentRail(),
      CanadaPostRail(),
    ]);
    expect(FundingRails.of(Jurisdiction.europe), const [
      ConfidentialSepaRail(),
      InstantSepaRail(),
      RegularSepaRail(),
    ]);
    expect(FundingRails.of(Jurisdiction.mexico), const [SpeiRail()]);
    expect(FundingRails.of(Jurisdiction.costaRica), const [
      SinpeMovilRail(),
      CostaRicaIbanCrcRail(),
      CostaRicaIbanUsdRail(),
    ]);
    expect(FundingRails.of(Jurisdiction.argentina), const [
      ArsBankTransferRail(),
    ]);
    expect(FundingRails.of(Jurisdiction.colombia), const [
      CopBankTransferRail(),
    ]);
  });

  test('every market can fund through a rail of its jurisdiction', () {
    for (final market in ExchangeCatalog.markets) {
      expect(FundingRails.of(market.jurisdiction), isNotEmpty);
    }
    expect(
      FundingRails.of(ExchangeCatalog.usd.jurisdiction),
      contains(const CostaRicaIbanUsdRail()),
    );
  });

  test('every rail asks for consent first (FUND-4)', () {
    for (final rail in FundingRails.all) {
      expect(rail.requiresConsent, isTrue, reason: rail.name);
    }
  });

  test(
    'pre-steps: COP picks a bank and amount, Confidential SEPA its IBAN',
    () {
      for (final rail in FundingRails.all) {
        expect(rail.preStep, switch (rail) {
          CopBankTransferRail() => FundingPreStep.institutionAndAmount,
          ConfidentialSepaRail() => FundingPreStep.virtualIban,
          ProcessorCodeRail() => FundingPreStep.none,
        }, reason: rail.name);
      }
    },
  );

  test('payment processor codes are the ones the app always sent', () {
    final codes = {
      for (final rail in FundingRails.all.whereType<ProcessorCodeRail>())
        rail.name: rail.paymentProcessorCode,
    };
    expect(codes, {
      'emailETransfer': 'IN_CAD_EMAIL_TRANSFER_APL',
      'bankWire': 'IN_CAD_WIRE_TRANSFER_SCU',
      'onlineBillPayment': 'IN_CAD_BILL_PAYMENT_APL',
      'canadaPost': 'IN_CAD_LOADHUB',
      'instantSepa': 'IN_EUR_CJ_IBAN',
      'regularSepa': 'IN_EUR_SEPA_DELUBAC',
      'spei': 'IN_MXN_BITSO_CLABE',
      'sinpeMovil': 'IN_CRC_RDV_SINPE',
      'costaRicaIbanCrc': 'IN_CRC_RDV_IBAN',
      'costaRicaIbanUsd': 'IN_USD_RDV_IBAN',
      'arsBankTransfer': 'IN_ARS_BITSO',
    });
  });

  test('the wire rail does not require the IBAN or account number it never '
      'shows (03 §12.4)', () {
    expect(const BankWireRail().fields, isNot(contains(InstructionField.iban)));
  });

  test('Canada Post presents a QR code, the others rows', () {
    const row = InstructionRow(InstructionField.transferCode, 'C0DE');
    expect(
      const CanadaPostRail().present(const [row]),
      const FundingInstructionQr('C0DE'),
    );
    expect(
      const SpeiRail().present(const [row]),
      const FundingInstructionRows([row]),
    );
  });
}
