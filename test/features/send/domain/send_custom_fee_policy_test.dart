import 'package:test/test.dart';

// Keep Send policies independent of the application namespace.
// ignore: avoid_relative_lib_imports
import '../../../../lib/features/send/domain/send_custom_fee_policy.dart';

void main() {
  const policy = SendCustomFeePolicy();
  SendFeeEvaluation rate(String text, {int floor = 25, int? size = 141}) =>
      policy.evaluate(
        text: text,
        mode: SendFeeInputMode.rate,
        minRelaySatPerKwu: floor,
        vsize: size,
      );
  SendFeeEvaluation total(String text, {int floor = 25, int? size = 141}) =>
      policy.evaluate(
        text: text,
        mode: SendFeeInputMode.total,
        minRelaySatPerKwu: floor,
        vsize: size,
      );

  test('network floor never falls below 0.1 and estimate rounds up', () {
    final value = rate('0.1', floor: 1);
    expect(value.isValid, isTrue);
    expect(value.relativeSatPerKwu, 25);
    expect(value.minimumRate, '0.1');
    expect(value.estimatedSats, BigInt.from(15));
    expect(value.absoluteSats, isNull);
    expect(value.rateWasAdjusted, isFalse);
  });

  test(
    'effective native rate is explicit when rounding in either direction',
    () {
      final down = rate('0.101');
      expect(down.relativeSatPerKwu, 25);
      expect(down.effectiveRate, '0.1');
      expect(down.rateWasAdjusted, isTrue);
      final up = rate('0.103');
      expect(up.relativeSatPerKwu, 26);
      expect(up.effectiveRate, '0.104');
      expect(up.rateWasAdjusted, isTrue);
      expect(up.estimatedSats, BigInt.from(15));
    },
  );

  test('exact half steps and near-half steps use the effective floor', () {
    expect(rate('0.098').relativeSatPerKwu, 25);
    expect(rate('0.097999').error, SendFeeInputError.belowMinimum);
    expect(rate('0.097').error, SendFeeInputError.belowMinimum);
  });

  test('live relay minimum is enforced without a silent increase', () {
    expect(rate('0.1', floor: 250).error, SendFeeInputError.belowMinimum);
    expect(rate('0.996', floor: 250).error, SendFeeInputError.belowMinimum);
    expect(rate('1', floor: 250).relativeSatPerKwu, 250);
    expect(rate('1', floor: 248).minimumRate, '0.992');
  });

  test(
    'rounded sat estimate cannot suppress a sub-one effective-rate warning',
    () {
      final below = rate('0.996', size: 100);
      expect(below.estimatedSats, BigInt.from(100));
      expect(below.effectiveRate, '0.996');
      expect(below.warnSubOne, isTrue);
      final roundedToOne = rate('0.999', size: 100);
      expect(roundedToOne.effectiveRate, '1');
      expect(roundedToOne.rateWasAdjusted, isTrue);
      expect(roundedToOne.warnSubOne, isFalse);
    },
  );

  test(
    'unknown vsize keeps a valid relative rate and no invented estimate',
    () {
      final value = rate('1', size: null);
      expect(value.isValid, isTrue);
      expect(value.relativeSatPerKwu, 250);
      expect(value.estimatedSats, isNull);
      expect(value.minimumTotalSats, isNull);
    },
  );

  test('Total stays exact and uses ceil of the live minimum times size', () {
    expect(total('14').error, SendFeeInputError.belowMinimum);
    final value = total('15');
    expect(value.absoluteSats, 15);
    expect(value.relativeSatPerKwu, isNull);
    expect(value.estimatedSats, BigInt.from(15));
    expect(value.minimumTotalSats, BigInt.from(15));
    expect(value.effectiveRate, '0.106');
    expect(value.effectiveRateIsApproximate, isTrue);
    expect(total('140', floor: 250).error, SendFeeInputError.belowMinimum);
    expect(total('141', floor: 250).absoluteSats, 141);
  });

  test('Total needs actual vsize to validate the floor', () {
    expect(total('15', size: null).error, SendFeeInputError.sizeUnavailable);
    expect(total('15', size: 0).error, SendFeeInputError.sizeUnavailable);
  });

  test('approximate Total rate cannot hide a sub-one ratio', () {
    final value = total('1999', size: 2000);
    expect(value.effectiveRate, '1');
    expect(value.effectiveRateIsApproximate, isTrue);
    expect(value.warnSubOne, isTrue);
    expect(total('2000', size: 2000).effectiveRateIsApproximate, isFalse);
    expect(total('2000', size: 2000).warnSubOne, isFalse);
  });

  test('incomplete and malformed input cannot be applied', () {
    for (final raw in ['', '.', '1.']) {
      expect(rate(raw).error, SendFeeInputError.incomplete, reason: raw);
    }
    for (final raw in ['NaN', 'Infinity', '-1', '1e3', '1,2']) {
      expect(rate(raw).error, SendFeeInputError.invalid, reason: raw);
    }
    expect(total('1.5').error, SendFeeInputError.invalid);
  });

  test('native integer boundaries preserve max and reject max plus one', () {
    expect(
      rate('36893488147419103.228').relativeSatPerKwu,
      9223372036854775807,
    );
    expect(rate('36893488147419103.232').error, SendFeeInputError.outOfRange);
    expect(total('9223372036854775807').absoluteSats, 9223372036854775807);
    expect(total('9223372036854775808').error, SendFeeInputError.outOfRange);
  });
}
