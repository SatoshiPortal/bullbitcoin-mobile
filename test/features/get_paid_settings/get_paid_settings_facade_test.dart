import 'package:bb_mobile/features/get_paid_settings/domain/usecases/get_get_paid_settings_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/publish_automated_keychain_backup_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/set_automated_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/get_paid_settings_locator.dart';
import 'package:bb_mobile/features/get_paid_settings/public/get_paid_settings_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late _MockKeychainManifestFacade manifest;
  late GetPaidSettingsFacade facade;

  setUp(() {
    manifest = _MockKeychainManifestFacade();
    facade = GetPaidSettingsFacade(
      getSettings: GetGetPaidSettingsUsecase(manifest),
      setAutomatedBackupEnabled: SetAutomatedBackupEnabledUsecase(manifest),
      publishBackup: PublishAutomatedKeychainBackupUsecase(manifest),
    );
  });

  test('exposes Bullnym backup state through the public facade', () async {
    when(manifest.getBackupState).thenAnswer(
      (_) async => const KeychainManifestBackupState(
        enabled: true,
        dirty: false,
        dirtyRevision: 3,
        lastAttemptedAt: 10,
        lastSucceededAt: 11,
        remoteGeneration: 2,
        remoteEtag: 'etag',
        contentHash: 'hash',
        unsupportedVersion: null,
      ),
    );

    final settings = await facade.getSettings();

    expect(settings.automatedBackupEnabled, isTrue);
    expect(settings.backupPending, isFalse);
    expect(settings.lastBackedUpAt, 11);
  });

  test('best-effort publication never fails a product flow', () async {
    when(manifest.backupNow).thenThrow(Exception('offline'));

    await expectLater(facade.publishBackupSnapshotIfEnabled(), completes);

    verify(manifest.backupNow).called(1);
  });

  test('locator publishes a mockable facade contract', () async {
    final locator = GetIt.asNewInstance();
    addTearDown(locator.reset);
    locator.registerSingleton<KeychainManifestFacade>(manifest);

    GetPaidSettingsLocator.setup(locator);

    expect(locator<GetPaidSettingsFacade>(), isA<GetPaidSettingsFacade>());
  });
}

final class _MockKeychainManifestFacade extends Mock
    implements KeychainManifestFacade {}
