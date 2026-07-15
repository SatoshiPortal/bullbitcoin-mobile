import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/constants.dart' show PayjoinConstants;
import 'package:flutter_test/flutter_test.dart';

SettingsEntity _settings({required int payjoinMinAmountSat}) => SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'USD',
  payjoinMinAmountSat: payjoinMinAmountSat,
);

void main() {
  group('SettingsEntity.isPayjoinEnabled', () {
    test('true for the default minimum amount', () {
      expect(
        _settings(
          payjoinMinAmountSat: PayjoinConstants.defaultMinAmountSat,
        ).isPayjoinEnabled,
        isTrue,
      );
    });

    test('true for any amount strictly below the ceiling', () {
      expect(
        _settings(
          payjoinMinAmountSat: PayjoinConstants.maxMinAmountSat - 1,
        ).isPayjoinEnabled,
        isTrue,
      );
    });

    test('false once the minimum amount is set to the ceiling sentinel — '
        'this is the "payjoin disabled" representation, not a real '
        'threshold (see PayjoinConstants.maxMinAmountSat)', () {
      expect(
        _settings(
          payjoinMinAmountSat: PayjoinConstants.maxMinAmountSat,
        ).isPayjoinEnabled,
        isFalse,
      );
    });
  });
}
