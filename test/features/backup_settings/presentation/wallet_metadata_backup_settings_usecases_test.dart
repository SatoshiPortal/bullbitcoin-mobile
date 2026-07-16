import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/failures/failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/entities/backup_settings_snapshot.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/backup_wallet_metadata_now_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/load_backup_settings_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/set_wallet_metadata_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/public/wallet_metadata_backup_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockMetadataBackup extends Mock implements WalletMetadataBackupFacade {}

class _MockGetWallets extends Mock implements GetWalletsUsecase {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late _MockMetadataBackup metadataBackup;

  setUp(() => metadataBackup = _MockMetadataBackup());

  test('loads metadata settings when no default wallets exist', () async {
    final getWallets = _MockGetWallets();
    final settings = _MockSettingsRepository();
    when(
      () => metadataBackup.getState(),
    ).thenAnswer((_) async => Ok(_state(enabled: true, dirty: true)));
    when(
      () => getWallets.execute(onlyDefaults: true),
    ).thenThrow(NoWalletsFoundException('none'));

    final result = await LoadBackupSettingsUsecase(
      getWallets,
      settings,
      metadataBackup,
    ).execute();

    final snapshot = _requireOk(result);
    expect(snapshot.walletMetadata.enabled, isTrue);
    expect(snapshot.walletMetadata.dirty, isTrue);
    verifyNever(() => settings.fetch());
  });

  test('explicit storage disclosure gates activation', () async {
    when(() => metadataBackup.getState()).thenAnswer((_) async => Ok(_state()));
    when(
      () => metadataBackup.setEnabled(true),
    ).thenAnswer((_) async => Ok(_state(enabled: true, dirty: true)));
    final usecase = SetWalletMetadataBackupEnabledUsecase(metadataBackup);

    final declined = await usecase.execute(
      enabled: true,
      disclosureAccepted: false,
    );
    expect(_requireOk(declined).enabled, isFalse);
    verifyNever(() => metadataBackup.setEnabled(any()));

    final accepted = await usecase.execute(
      enabled: true,
      disclosureAccepted: true,
    );
    expect(_requireOk(accepted).enabled, isTrue);
    verify(() => metadataBackup.setEnabled(true)).called(1);
  });

  test('manual backup maps a stored blob to saved', () async {
    when(() => metadataBackup.backupNow()).thenAnswer(
      (_) async => const Ok(
        WalletMetadataPublishOutcome(
          status: WalletMetadataPublishStatus.stored,
          remoteGeneration: 2,
          remoteEtag:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
      ),
    );
    when(
      () => metadataBackup.getState(),
    ).thenAnswer((_) async => Ok(_state(enabled: true)));

    final result = await BackupWalletMetadataNowUsecase(
      metadataBackup,
    ).execute();

    expect(_requireOk(result).status, WalletMetadataBackupNowStatus.saved);
  });

  test('maps the last verified publication timestamp', () async {
    when(
      () => metadataBackup.getState(),
    ).thenAnswer((_) async => Ok(_state(lastSucceededAt: 1234)));
    final getWallets = _MockGetWallets();
    final settings = _MockSettingsRepository();
    when(
      () => getWallets.execute(onlyDefaults: true),
    ).thenThrow(NoWalletsFoundException('none'));

    final result = await LoadBackupSettingsUsecase(
      getWallets,
      settings,
      metadataBackup,
    ).execute();

    expect(
      _requireOk(result).walletMetadata.lastVerifiedAt,
      DateTime.fromMillisecondsSinceEpoch(1234000, isUtc: true),
    );
  });

  test('unexpected facade exceptions become typed failures', () async {
    when(() => metadataBackup.backupNow()).thenThrow(Exception('private'));
    final result = await BackupWalletMetadataNowUsecase(
      metadataBackup,
    ).execute();
    expect(
      result,
      isA<Err<WalletMetadataBackupNowResult, BackupSettingsFailure>>(),
    );
  });
}

WalletMetadataBackupState _state({
  bool enabled = false,
  bool dirty = false,
  int? lastSucceededAt,
}) {
  return WalletMetadataBackupState(
    enabled: enabled,
    dirty: dirty,
    dirtyRevision: dirty ? 1 : 0,
    lastAttemptedAt: null,
    lastSucceededAt: lastSucceededAt,
    verifiedHead: null,
    unsupportedNewerEnvelope: null,
    recoveryBlock: null,
  );
}

T _requireOk<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw TestFailure('unexpected $failure'),
};
