import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/export_signing_key_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetDefaultSeedUsecase extends Mock
    implements GetDefaultSeedUsecase {}

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

void main() {
  late _MockGetDefaultSeedUsecase getDefaultSeed;
  late _MockGetSettingsUsecase getSettings;
  late ExportSigningKeyUsecase usecase;

  final seed = Seed.bytes(
    bytes: Uint8List.fromList(List<int>.generate(32, (index) => index)),
    masterFingerprint: '5A3469B6',
  );

  setUp(() {
    getDefaultSeed = _MockGetDefaultSeedUsecase();
    getSettings = _MockGetSettingsUsecase();
    usecase = ExportSigningKeyUsecase(
      getDefaultSeedUsecase: getDefaultSeed,
      getSettingsUsecase: getSettings,
    );
    when(
      () => getDefaultSeed.execute(environment: any(named: 'environment')),
    ).thenAnswer((_) async => seed);
  });

  test('exports the compatibility signing key on mainnet', () async {
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );

    final result = await usecase.execute(account: 0);

    expect(result, isA<Ok<String, SettingsFailure>>());
    final descriptorKey = (result as Ok<String, SettingsFailure>).value;
    expect(
      descriptorKey,
      '[5a3469b6/48h/0h/0h/2h]'
      'xpub6ECRn8ehyKtWTtyqrmt8Dt5Vs7VSbh9Y8Zcyq7vcLEufmoo86VxqdYBEHEtt'
      '3H342PrmAiUyUkdNiFzdmGNEyUg7xLYt922WvfMEn2h8pnR',
    );
    verify(
      () => getDefaultSeed.execute(environment: Environment.mainnet),
    ).called(1);
  });

  test(
    'exports the testnet compatibility key for the selected account',
    () async {
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.testnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      );

      final result = await usecase.execute(account: 7);

      expect(result, isA<Ok<String, SettingsFailure>>());
      expect(
        (result as Ok<String, SettingsFailure>).value,
        startsWith('[5a3469b6/48h/1h/7h/2h]tpub'),
      );
      verify(
        () => getDefaultSeed.execute(environment: Environment.testnet),
      ).called(1);
    },
  );

  test('maps seed lookup errors to a settings failure', () async {
    when(
      () => getDefaultSeed.execute(environment: any(named: 'environment')),
    ).thenThrow(Exception('missing seed'));
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );

    final result = await usecase.execute(account: 0);

    expect(result, isA<Err<String, SettingsFailure>>());
    expect(
      (result as Err<String, SettingsFailure>).failure,
      isA<SettingsSigningKeyExportFailure>(),
    );
  });
}
