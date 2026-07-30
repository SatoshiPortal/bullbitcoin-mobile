import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:flutter_test/flutter_test.dart';

/// Settings that break no rule, for tests to bend one field at a time.
const _valid = AutoSwap(
  enabled: true,
  balanceThresholdSats: 100000,
  triggerBalanceSats: 200000,
  feeThresholdPercent: 3,
  recipientWalletId: 'wallet-id',
);

void main() {
  group('AutoSwap.violation', () {
    test('accepts settings that break no rule', () {
      expect(_valid.violation, isNull);
    });

    test('requires a recipient wallet only while enabled', () {
      expect(
        _valid.copyWith(recipientWalletId: null).violation,
        AutoSwapSettingsViolation.recipientWalletMissing,
      );

      // Switching auto swap off must not demand a recipient, or turning the
      // feature off would be impossible.
      expect(
        _valid.copyWith(enabled: false, recipientWalletId: null).violation,
        isNull,
      );
    });

    test('rejects a target balance below the minimum', () {
      expect(
        _valid.copyWith(balanceThresholdSats: 49999).violation,
        AutoSwapSettingsViolation.balanceThresholdTooLow,
      );
      expect(
        _valid
            .copyWith(balanceThresholdSats: 50000, triggerBalanceSats: 100000)
            .violation,
        isNull,
      );
    });

    test('rejects a trigger balance below twice the target', () {
      expect(
        _valid.copyWith(triggerBalanceSats: 199999).violation,
        AutoSwapSettingsViolation.triggerBalanceTooLow,
      );
      expect(_valid.copyWith(triggerBalanceSats: 200000).violation, isNull);
    });

    test('rejects a fee ceiling above the maximum', () {
      expect(
        _valid.copyWith(feeThresholdPercent: 10.1).violation,
        AutoSwapSettingsViolation.feeThresholdTooHigh,
      );
      expect(_valid.copyWith(feeThresholdPercent: 10).violation, isNull);
    });

    test('reports the recipient rule before the amount rules', () {
      final broken = _valid.copyWith(
        recipientWalletId: null,
        balanceThresholdSats: 1,
        triggerBalanceSats: 1,
        feeThresholdPercent: 99,
      );

      expect(
        broken.violation,
        AutoSwapSettingsViolation.recipientWalletMissing,
      );
    });

    test('reports the balance rule before the trigger rule', () {
      // Both broken; the target is the field the user must fix first.
      expect(
        _valid
            .copyWith(balanceThresholdSats: 1000, triggerBalanceSats: 1)
            .violation,
        AutoSwapSettingsViolation.balanceThresholdTooLow,
      );
    });

    test('a persisted row that breaks a rule still deserializes', () {
      // The rules are not constructor-enforced on purpose: settings written by
      // an older version must still load, or the feature becomes unopenable.
      final legacy = AutoSwap.fromJson(const {
        'enabled': true,
        'balanceThresholdSats': 10000,
        'triggerBalanceSats': 15000,
        'feeThresholdPercent': 50.0,
        'blockTillNextExecution': false,
        'alwaysBlock': false,
        'recipientWalletId': null,
        'showWarning': true,
      });

      expect(legacy.balanceThresholdSats, 10000);
      expect(legacy.violation, isNotNull);
    });
  });
}
