import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/entities/fiat_settlement.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/fiat_settlement_failure.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/fiat_settlement_failure_mapping.dart';
import 'package:flutter_test/flutter_test.dart';

BullnymFailure _rejected(String code, {int? statusCode}) {
  return BullnymFailure.serverRejectedRequest(
    code: code,
    logMessage: 'x',
    statusCode: statusCode,
    retryable: false,
  );
}

void main() {
  group('mapBullnymToFiatSettlementFailure', () {
    test('KYC code maps to kycRequired', () {
      expect(
        mapBullnymToFiatSettlementFailure(
          _rejected(fiatSettlementKycRequiredCode),
        ).kind,
        FiatSettlementFailureKind.kycRequired,
      );
    });

    test('both credential codes map to credentialProblem', () {
      for (final code in [
        fiatSettlementCredentialRequiredCode,
        fiatSettlementCredentialInvalidCode,
      ]) {
        expect(
          mapBullnymToFiatSettlementFailure(_rejected(code)).kind,
          FiatSettlementFailureKind.credentialProblem,
        );
      }
    });

    test('a 503 rejection maps to dependencyUnavailable', () {
      expect(
        mapBullnymToFiatSettlementFailure(
          _rejected('ServiceUnavailable', statusCode: 503),
        ).kind,
        FiatSettlementFailureKind.dependencyUnavailable,
      );
      expect(
        mapBullnymToFiatSettlementFailure(
          const BullnymFailure.unexpectedHttpStatus(statusCode: 503),
        ).kind,
        FiatSettlementFailureKind.dependencyUnavailable,
      );
    });

    test('network and timeout map to bullnymUnreachable', () {
      expect(
        mapBullnymToFiatSettlementFailure(
          const BullnymFailure.network(logMessage: 'x'),
        ).kind,
        FiatSettlementFailureKind.bullnymUnreachable,
      );
      expect(
        mapBullnymToFiatSettlementFailure(
          const BullnymFailure.timeout(logMessage: 'x'),
        ).kind,
        FiatSettlementFailureKind.bullnymUnreachable,
      );
    });

    test('invalid input maps to invalidInput', () {
      expect(
        mapBullnymToFiatSettlementFailure(
          const BullnymFailure.invalidInput('x'),
        ).kind,
        FiatSettlementFailureKind.invalidInput,
      );
    });

    test('an unrecognized server code maps to unexpected', () {
      expect(
        mapBullnymToFiatSettlementFailure(_rejected('SomethingElse')).kind,
        FiatSettlementFailureKind.unexpected,
      );
    });
  });

  group('entities', () {
    test('mode derives from percentage at the boundaries', () {
      expect(
        fiatSettlementModeForPercentage(0),
        FiatSettlementMode.bitcoinOnly,
      );
      expect(fiatSettlementModeForPercentage(1), FiatSettlementMode.mixed);
      expect(fiatSettlementModeForPercentage(99), FiatSettlementMode.mixed);
      expect(fiatSettlementModeForPercentage(100), FiatSettlementMode.fiatOnly);
    });

    test('product wire mapping round-trips', () {
      for (final product in FiatSettlementProduct.values) {
        expect(FiatSettlementProduct.fromWire(product.wire), product);
      }
    });

    test('currency codes cover exactly the seven approved currencies', () {
      expect(FiatCurrency.values.map((c) => c.code).toList(), [
        'CAD',
        'EUR',
        'MXN',
        'CRC',
        'COP',
        'ARS',
        'USD',
      ]);
      expect(FiatCurrency.fromCode('EUR'), FiatCurrency.eur);
      expect(FiatCurrency.fromCode('ZZZ'), isNull);
    });
  });
}
