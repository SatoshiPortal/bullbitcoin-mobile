import 'dart:async';

import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/backup_wallet_now_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/delete_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_wallet_backup_recovery_outcome_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_wallet_backup_contents_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/retry_wallet_backup_recovery_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/set_wallet_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/watch_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWalletBackupFacade extends Mock implements WalletBackupFacade {}

void main() {
  late StreamController<Result<WalletBackupState, WalletBackupFailure>>
  backupStates;
  late _MockGetWalletsUsecase getWallets;
  late _MockWalletBackupFacade walletBackup;
  late BackupSettingsCubit cubit;

  const recoveryOutcome = WalletBackupRecoveryOutcome(
    status: WalletBackupRecoveryStatus.restored,
    completedAt: 42,
    restoredCount: 3,
    failedCount: 0,
  );

  WalletBackupState backupState({required bool dirty}) => WalletBackupState(
    enabled: true,
    dirty: dirty,
    dirtyRevision: dirty ? 2 : 1,
    lastAttemptedAt: null,
    lastSucceededAt: null,
    remoteGeneration: 0,
    remoteEtag: null,
    contentHash: null,
    unsupportedVersion: null,
  );

  setUp(() {
    backupStates = StreamController.broadcast(sync: true);
    getWallets = _MockGetWalletsUsecase();
    walletBackup = _MockWalletBackupFacade();

    when(
      () => getWallets.execute(onlyDefaults: true),
    ).thenAnswer((_) async => []);
    when(() => walletBackup.getLastRecoveryOutcome()).thenAnswer(
      (_) async => const Ok<WalletBackupRecoveryOutcome?, WalletBackupFailure>(
        recoveryOutcome,
      ),
    );
    when(
      () => walletBackup.watchState(),
    ).thenAnswer((_) => backupStates.stream);
    when(() => walletBackup.getContents()).thenAnswer(
      (_) async =>
          Ok(WalletBackupContents(wallets: const [], metadata: const [])),
    );

    cubit = BackupSettingsCubit(
      getWalletsUsecase: getWallets,
      settingsRepository: _MockSettingsRepository(),
      watchWalletBackup: WatchWalletBackupUsecase(walletBackup),
      setWalletBackupEnabled: SetWalletBackupEnabledUsecase(walletBackup),
      backupWalletNow: BackupWalletNowUsecase(walletBackup),
      deleteWalletBackup: DeleteWalletBackupUsecase(walletBackup),
      getRecoveryOutcome: GetWalletBackupRecoveryOutcomeUsecase(walletBackup),
      getContents: GetWalletBackupContentsUsecase(walletBackup),
      retryRecovery: RetryWalletBackupRecoveryUsecase(walletBackup),
    );
  });

  tearDown(() async {
    await cubit.close();
    await backupStates.close();
  });

  test(
    'keeps live clean/dirty state and the persisted recovery outcome',
    () async {
      await cubit.checkBackupStatus();

      final clean = backupState(dirty: false);
      backupStates.add(Ok(clean));
      expect(cubit.state.walletBackup, same(clean));
      expect(cubit.state.lastRecoveryOutcome, same(recoveryOutcome));
      expect(cubit.state.status, BackupSettingsStatus.success);
      expect(cubit.state.contents, isNotNull);

      final dirty = backupState(dirty: true);
      backupStates.add(Ok(dirty));
      expect(cubit.state.walletBackup, same(dirty));
    },
  );

  test('exposes backup progress only while the operation is running', () async {
    final result = Completer<Result<void, WalletBackupFailure>>();
    when(() => walletBackup.backupNow()).thenAnswer((_) => result.future);

    final pending = cubit.backupWalletNow();
    expect(
      cubit.state.walletBackupOperation,
      WalletBackupSettingsOperation.backingUp,
    );

    result.complete(const Ok<void, WalletBackupFailure>(null));
    await pending;
    expect(
      cubit.state.walletBackupOperation,
      WalletBackupSettingsOperation.idle,
    );
    expect(cubit.state.failure, isNull);
  });

  test('surfaces a typed backup failure and returns to idle', () async {
    when(() => walletBackup.backupNow()).thenAnswer(
      (_) async => const Err<void, WalletBackupFailure>(
        WalletBackupRemoteUnavailableFailure('backend details'),
      ),
    );

    await cubit.backupWalletNow();

    expect(cubit.state.failure, isA<BackupSettingsUnavailableFailure>());
    expect(
      cubit.state.walletBackupOperation,
      WalletBackupSettingsOperation.idle,
    );
  });

  test('keeps a contents read failure local and allows retry', () async {
    when(() => walletBackup.getContents()).thenAnswer(
      (_) async => const Err<WalletBackupContents, WalletBackupFailure>(
        WalletBackupStorageFailure(),
      ),
    );

    await cubit.loadContents();

    expect(cubit.state.contents, isNull);
    expect(cubit.state.contentsLoading, isFalse);
    expect(cubit.state.failure, isNull);

    final contents = WalletBackupContents(
      wallets: const [],
      metadata: const [],
    );
    when(
      () => walletBackup.getContents(),
    ).thenAnswer((_) async => Ok(contents));
    await cubit.loadContents();

    expect(cubit.state.contents, same(contents));
  });
}
