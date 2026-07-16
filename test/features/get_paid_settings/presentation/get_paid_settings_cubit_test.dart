import 'dart:async';

import 'package:bb_mobile/features/get_paid_settings/domain/get_paid_settings.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/delete_automated_keychain_backup_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/get_get_paid_settings_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/publish_automated_keychain_backup_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/set_automated_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/presentation/get_paid_settings_cubit.dart';
import 'package:bb_mobile/features/get_paid_settings/presentation/get_paid_settings_state.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late StreamController<GetPaidSettings> settings;
  late _ManifestFacade manifest;
  late GetPaidSettingsCubit cubit;

  setUp(() {
    settings = StreamController<GetPaidSettings>();
    manifest = _ManifestFacade();
    when(
      manifest.watchBackupState,
    ).thenAnswer((_) => settings.stream.map(_backupState));
    when(() => manifest.setBackupEnabled(any())).thenAnswer((_) async {});
    when(manifest.backupNow).thenAnswer((_) async {});
    when(
      () => manifest.deleteRemoteBackup(confirmed: true),
    ).thenAnswer((_) async {});
    cubit = GetPaidSettingsCubit(
      getSettings: GetGetPaidSettingsUsecase(manifest),
      setEnabled: SetAutomatedBackupEnabledUsecase(manifest),
      publish: PublishAutomatedKeychainBackupUsecase(manifest),
      deleteBackup: DeleteAutomatedKeychainBackupUsecase(manifest),
    );
  });

  tearDown(() async {
    await cubit.close();
    await settings.close();
  });

  test('keeps controls unready until durable state emits', () async {
    await cubit.load();
    expect(cubit.state.status, GetPaidSettingsStatus.loading);
    expect(cubit.state.settings, isNull);

    settings.add(_enabledPending);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.status, GetPaidSettingsStatus.loaded);
    expect(cubit.state.settings?.automatedBackupEnabled, isTrue);
    expect(cubit.state.settings?.backupPending, isTrue);
  });

  test('manual backup failures remain visible and retryable', () async {
    await cubit.load();
    settings.add(_enabledPending);
    await Future<void>.delayed(Duration.zero);
    when(manifest.backupNow).thenThrow(StateError('offline'));

    await cubit.backupNow();

    expect(cubit.state.status, GetPaidSettingsStatus.failure);
    expect(cubit.state.backingUp, isFalse);
    verify(manifest.backupNow).called(1);
  });

  test(
    'remote deletion is unavailable until automatic backup is disabled',
    () async {
      await cubit.load();
      settings.add(_enabledPending);
      await Future<void>.delayed(Duration.zero);

      await cubit.deleteRemoteBackup();
      verifyNever(() => manifest.deleteRemoteBackup(confirmed: true));

      settings.add(_disabledBackedUp);
      await Future<void>.delayed(Duration.zero);
      await cubit.deleteRemoteBackup();
      verify(() => manifest.deleteRemoteBackup(confirmed: true)).called(1);
    },
  );
}

const _enabledPending = GetPaidSettings(
  automatedBackupEnabled: true,
  backupPending: true,
  lastBackedUpAt: null,
  unsupportedVersion: null,
);

const _disabledBackedUp = GetPaidSettings(
  automatedBackupEnabled: false,
  backupPending: false,
  lastBackedUpAt: 10,
  unsupportedVersion: null,
);

KeychainManifestBackupState _backupState(GetPaidSettings settings) =>
    KeychainManifestBackupState(
      enabled: settings.automatedBackupEnabled,
      dirty: settings.backupPending,
      dirtyRevision: 1,
      lastAttemptedAt: null,
      lastSucceededAt: settings.lastBackedUpAt,
      remoteGeneration: 0,
      remoteEtag: null,
      contentHash: null,
      unsupportedVersion: settings.unsupportedVersion,
    );

final class _ManifestFacade extends Mock implements KeychainManifestFacade {}
