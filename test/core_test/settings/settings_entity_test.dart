import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SettingsEntity payjoin defaults', () {
    SettingsEntity buildEntity() => const SettingsEntity(
      environment: Environment.mainnet,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'USD',
    );

    test('payjoin is disabled by default', () {
      expect(buildEntity().isPayjoinEnabled, isFalse);
    });

    test(
      'payjoin min amount defaults to PayjoinConstants.defaultMinAmountSat',
      () {
        expect(
          buildEntity().payjoinMinAmountSat,
          PayjoinConstants.defaultMinAmountSat,
        );
      },
    );

    test(
      'payjoin expiry defaults to PayjoinConstants.defaultExpireAfterSec',
      () {
        expect(
          buildEntity().payjoinExpireAfterSec,
          PayjoinConstants.defaultExpireAfterSec,
        );
      },
    );

    test('toggling payjoin enabled does not touch the min amount', () {
      final entity = buildEntity().copyWith(
        isPayjoinEnabled: true,
        payjoinMinAmountSat: 50000,
      );
      final toggledOff = entity.copyWith(isPayjoinEnabled: false);

      // Regression guard for the bug a dedicated boolean column avoids: a
      // sentinel-based "enabled" (derived from minAmountSat) would reset a
      // custom amount when toggled off/on. A dedicated column can't.
      expect(toggledOff.payjoinMinAmountSat, 50000);
    });
  });
}
