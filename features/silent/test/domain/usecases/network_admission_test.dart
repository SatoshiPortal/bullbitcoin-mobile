import '../../sp_fakes.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:silent/src/domain/usecases/get_sp_feature_gate_usecase.dart';
import 'package:primitives/primitives.dart';

class SettingsMock extends Mock implements Preferences {}

void main() {
  test('SP feature gate must be closed while app is on regtest', () async {
    final settings = SettingsMock();
    when(() => settings.fetch()).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.regtest,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
          isSuperuser: true,
          isDevModeEnabled: true,
        ),
      ),
    );
    expect(
      await GetSpFeatureGateUsecase(
        settingsRepository: settings,
        configRepository: FakeSpBackendConfigRepository(),
      ).execute(),
      isFalse,
    );
  });
}
