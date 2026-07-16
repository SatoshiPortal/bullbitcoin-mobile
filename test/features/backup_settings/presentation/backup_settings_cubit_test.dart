import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/entities/backup_settings_snapshot.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/backup_wallet_metadata_now_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/delete_remote_wallet_metadata_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/load_backup_settings_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/set_wallet_metadata_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoadSettings extends Mock implements LoadBackupSettingsUsecase {}

class _MockSetMetadataBackup extends Mock
    implements SetWalletMetadataBackupEnabledUsecase {}

class _MockBackupMetadataNow extends Mock
    implements BackupWalletMetadataNowUsecase {}

class _MockDeleteRemoteMetadata extends Mock
    implements DeleteRemoteWalletMetadataBackupUsecase {}

void main() {
  late _MockLoadSettings loadSettings;
  late _MockSetMetadataBackup setMetadataBackup;
  late _MockBackupMetadataNow backupMetadataNow;
  late _MockDeleteRemoteMetadata deleteRemoteMetadata;
  late BackupSettingsCubit cubit;

  setUp(() {
    loadSettings = _MockLoadSettings();
    setMetadataBackup = _MockSetMetadataBackup();
    backupMetadataNow = _MockBackupMetadataNow();
    deleteRemoteMetadata = _MockDeleteRemoteMetadata();
    cubit = BackupSettingsCubit(
      loadSettings: loadSettings,
      setMetadataBackupEnabled: setMetadataBackup,
      backupMetadataNow: backupMetadataNow,
      deleteRemoteMetadata: deleteRemoteMetadata,
    );
  });

  tearDown(() => cubit.close());

  test('loads wallet and metadata backup state from one usecase', () async {
    final verifiedAt = DateTime.utc(2026, 7, 16, 12);
    when(() => loadSettings.execute()).thenAnswer(
      (_) async => Ok(
        BackupSettingsSnapshot(
          isDefaultPhysicalBackupTested: true,
          lastPhysicalBackup: null,
          isDefaultEncryptedBackupTested: false,
          lastEncryptedBackup: null,
          walletMetadata: WalletMetadataBackupSettingsSnapshot(
            enabled: true,
            dirty: true,
            blocked: false,
            lastVerifiedAt: verifiedAt,
          ),
        ),
      ),
    );

    await cubit.checkBackupStatus();

    expect(cubit.state.status, BackupSettingsStatus.success);
    expect(cubit.state.isDefaultPhysicalBackupTested, isTrue);
    expect(cubit.state.metadataBackupEnabled, isTrue);
    expect(cubit.state.metadataBackupDirty, isTrue);
    expect(cubit.state.metadataBackupLastVerifiedAt, verifiedAt);
  });

  test('delegates metadata activation and clears the busy state', () async {
    when(
      () => setMetadataBackup.execute(enabled: true, disclosureAccepted: true),
    ).thenAnswer(
      (_) async => const Ok(
        WalletMetadataBackupSettingsSnapshot(
          enabled: true,
          dirty: true,
          blocked: false,
        ),
      ),
    );

    await cubit.setMetadataBackupEnabled(
      enabled: true,
      disclosureAccepted: true,
    );

    verify(
      () => setMetadataBackup.execute(enabled: true, disclosureAccepted: true),
    ).called(1);
    expect(cubit.state.metadataBackupEnabled, isTrue);
    expect(cubit.state.metadataBackupBusy, isFalse);
  });

  test('manual backup maps verified publication to a saved action', () async {
    when(() => backupMetadataNow.execute()).thenAnswer(
      (_) async => const Ok(
        WalletMetadataBackupNowResult(
          status: WalletMetadataBackupNowStatus.saved,
          settings: WalletMetadataBackupSettingsSnapshot(
            enabled: true,
            dirty: false,
            blocked: false,
          ),
        ),
      ),
    );

    await cubit.backupMetadataNow();

    expect(
      cubit.state.metadataActionStatus,
      WalletMetadataBackupActionStatus.saved,
    );
    expect(cubit.state.metadataBackupDirty, isFalse);
    expect(cubit.state.metadataBackupBusy, isFalse);
  });

  test('metadata failure clears busy state and remains sanitized', () async {
    when(() => backupMetadataNow.execute()).thenAnswer(
      (_) async =>
          const Err(BackupSettingsUnexpectedFailure('metadata backup failed')),
    );

    await cubit.backupMetadataNow();

    expect(
      cubit.state.metadataActionStatus,
      WalletMetadataBackupActionStatus.failed,
    );
    expect(cubit.state.metadataBackupBusy, isFalse);
    expect(cubit.state.failure?.logMessage, 'metadata backup failed');
  });

  test(
    'successful remote deletion clears checkpoint and reports deletion',
    () async {
      when(() => deleteRemoteMetadata.execute()).thenAnswer(
        (_) async => const Ok(
          WalletMetadataBackupSettingsSnapshot(
            enabled: false,
            dirty: false,
            blocked: false,
          ),
        ),
      );

      await cubit.deleteRemoteMetadata();

      expect(
        cubit.state.metadataActionStatus,
        WalletMetadataBackupActionStatus.deleted,
      );
      expect(cubit.state.metadataBackupHasRemote, isFalse);
      expect(cubit.state.metadataBackupLastVerifiedAt, isNull);
      expect(cubit.state.metadataBackupBusy, isFalse);
    },
  );

  test('a settings refresh clears a stale metadata action', () async {
    when(() => backupMetadataNow.execute()).thenAnswer(
      (_) async => const Ok(
        WalletMetadataBackupNowResult(
          status: WalletMetadataBackupNowStatus.saved,
          settings: WalletMetadataBackupSettingsSnapshot(
            enabled: true,
            dirty: false,
            blocked: false,
          ),
        ),
      ),
    );
    when(() => loadSettings.execute()).thenAnswer(
      (_) async =>
          const Err(BackupSettingsUnexpectedFailure('settings refresh failed')),
    );

    await cubit.backupMetadataNow();
    await cubit.checkBackupStatus();

    expect(cubit.state.status, BackupSettingsStatus.error);
    expect(
      cubit.state.metadataActionStatus,
      WalletMetadataBackupActionStatus.idle,
    );
    expect(cubit.state.failure?.logMessage, 'settings refresh failed');
  });

  test('does not run metadata actions while settings are loading', () async {
    final load =
        Completer<Result<BackupSettingsSnapshot, BackupSettingsFailure>>();
    when(() => loadSettings.execute()).thenAnswer((_) => load.future);

    final checking = cubit.checkBackupStatus();
    await Future<void>.delayed(Duration.zero);
    await cubit.setMetadataBackupEnabled(
      enabled: true,
      disclosureAccepted: true,
    );
    await cubit.backupMetadataNow();

    verifyNever(
      () => setMetadataBackup.execute(
        enabled: any(named: 'enabled'),
        disclosureAccepted: any(named: 'disclosureAccepted'),
      ),
    );
    verifyNever(() => backupMetadataNow.execute());

    load.complete(
      const Ok(
        BackupSettingsSnapshot(
          isDefaultPhysicalBackupTested: false,
          lastPhysicalBackup: null,
          isDefaultEncryptedBackupTested: false,
          lastEncryptedBackup: null,
          walletMetadata: WalletMetadataBackupSettingsSnapshot(
            enabled: false,
            dirty: false,
            blocked: false,
          ),
        ),
      ),
    );
    await checking;
    expect(cubit.state.status, BackupSettingsStatus.success);
  });
}
