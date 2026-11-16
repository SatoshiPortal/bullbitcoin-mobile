import 'dart:async';

import 'package:bb_mobile/features/app_startup/public/foreground_electrum_startup.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

SettingsEntity _settings(Environment environment, {bool developer = false}) =>
    SettingsEntity(
      environment: environment,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'USD',
      isSuperuser: developer,
      isDevModeEnabled: developer,
    );

void main() {
  for (final environment in Environment.values) {
    test('awaits storage readiness for captured ${environment.name}', () async {
      final ready = Completer<bool>();
      NetworkEnv? captured;
      var finished = false;
      final preparation = ForegroundElectrumStartup.prepare(
        capturedSettings: _settings(environment, developer: true),
        prepareElectrum: (selected) {
          captured = selected;
          return ready.future;
        },
      ).then((_) => finished = true);
      await Future<void>.delayed(Duration.zero);
      expect(captured, environment.networkEnv);
      expect(finished, isFalse);
      ready.complete(true);
      await preparation;
      expect(finished, isTrue);
    });
  }

  for (final environment in [Environment.testnet, Environment.regtest]) {
    test(
      'refuses unauthorized ${environment.name} before provisioning',
      () async {
        var calls = 0;
        await expectLater(
          ForegroundElectrumStartup.prepare(
            capturedSettings: _settings(environment),
            prepareElectrum: (_) async {
              calls++;
              return true;
            },
          ),
          throwsA(isA<ForegroundElectrumPreparationException>()),
        );
        expect(calls, 0);
      },
    );
  }

  test('allows mainnet without developer flags', () async {
    NetworkEnv? captured;
    await ForegroundElectrumStartup.prepare(
      capturedSettings: _settings(Environment.mainnet),
      prepareElectrum: (selected) async {
        captured = selected;
        return true;
      },
    );
    expect(captured, NetworkEnv.mainnet);
  });

  test('storage failure prevents bootstrap completion', () async {
    await expectLater(
      ForegroundElectrumStartup.prepare(
        capturedSettings: _settings(Environment.regtest, developer: true),
        prepareElectrum: (_) async => false,
      ),
      throwsA(isA<ForegroundElectrumPreparationException>()),
    );
  });
}
