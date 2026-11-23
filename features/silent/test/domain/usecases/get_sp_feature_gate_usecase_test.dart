import 'package:primitives/primitives.dart'
    show BitcoinNetwork, BitcoinUnit, Ok;

import '../../sp_fakes.dart';

import 'package:preferences/preferences.dart';
import 'package:silent/src/domain/usecases/get_sp_feature_gate_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsRepository extends Mock implements Preferences {}

SettingsEntity _settings({bool? isSuperuser, bool? isDevModeEnabled}) =>
    const SettingsEntity(
      environment: Environment.mainnet,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'CAD',
      isSuperuser: null,
    ).copyWith(isSuperuser: isSuperuser, isDevModeEnabled: isDevModeEnabled);

void main() {
  late _MockSettingsRepository settingsRepo;
  late GetSpFeatureGateUsecase usecase;

  setUp(() async {
    settingsRepo = _MockSettingsRepository();
    final config = FakeSpBackendConfigRepository();
    await config.save(spBackendConfig(network: BitcoinNetwork.mainnet));
    usecase = GetSpFeatureGateUsecase(
      settingsRepository: settingsRepo,
      configRepository: config,
    );
  });

  Future<bool> gateWith({bool? isSuperuser, bool? isDevModeEnabled}) {
    when(() => settingsRepo.fetch()).thenAnswer(
      (_) async => Ok(
        _settings(isSuperuser: isSuperuser, isDevModeEnabled: isDevModeEnabled),
      ),
    );
    return usecase.execute();
  }

  group('GetSpFeatureGateUsecase', () {
    test('enabled only when superuser and dev mode are both true', () async {
      expect(await gateWith(isSuperuser: true, isDevModeEnabled: true), isTrue);
    });

    test('disabled when dev mode is off', () async {
      expect(
        await gateWith(isSuperuser: true, isDevModeEnabled: false),
        isFalse,
      );
    });

    test('disabled when superuser is off', () async {
      expect(
        await gateWith(isSuperuser: false, isDevModeEnabled: true),
        isFalse,
      );
    });

    test('disabled when both are off', () async {
      expect(
        await gateWith(isSuperuser: false, isDevModeEnabled: false),
        isFalse,
      );
    });

    test('null superuser is treated as off', () async {
      expect(
        await gateWith(isSuperuser: null, isDevModeEnabled: true),
        isFalse,
      );
    });

    test('null dev mode is treated as off', () async {
      expect(
        await gateWith(isSuperuser: true, isDevModeEnabled: null),
        isFalse,
      );
    });

    test('both null is treated as off', () async {
      expect(
        await gateWith(isSuperuser: null, isDevModeEnabled: null),
        isFalse,
      );
    });
  });
}
