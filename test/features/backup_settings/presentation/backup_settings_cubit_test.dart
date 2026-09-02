import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/backup_wallet_now_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/delete_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/export_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_wallet_backup_contents_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/import_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/retry_wallet_backup_recovery_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/set_wallet_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/set_wallet_backup_server_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/watch_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockWalletBackupFacade extends Mock implements WalletBackupFacade {}

class _MockWalletBackupFileRepository extends Mock
    implements WalletBackupFileRepository {}

void main() {
  late StreamController<Result<WalletBackupState, WalletBackupFailure>> states;
  late _MockWalletBackupFacade backup;
  late _MockWalletBackupFileRepository files;
  late BackupSettingsCubit cubit;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    states = StreamController.broadcast(sync: true);
    backup = _MockWalletBackupFacade();
    files = _MockWalletBackupFileRepository();
    when(() => backup.watchState()).thenAnswer((_) => states.stream);
    when(() => backup.getContents()).thenAnswer(
      (_) async => const Ok(
        WalletBackupContents(
          labelCount: 0,
          frozenCoinCount: 0,
          walletPreferenceCount: 0,
        ),
      ),
    );

    cubit = BackupSettingsCubit(
      watchWalletBackup: WatchWalletBackupUsecase(backup),
      setWalletBackupEnabled: SetWalletBackupEnabledUsecase(backup),
      setWalletBackupServer: SetWalletBackupServerUsecase(backup),
      backupWalletNow: BackupWalletNowUsecase(backup),
      deleteWalletBackup: DeleteWalletBackupUsecase(backup),
      getContents: GetWalletBackupContentsUsecase(backup),
      retryRecovery: RetryWalletBackupRecoveryUsecase(backup),
      exportFile: ExportWalletBackupFileUsecase(backup, files),
      importFile: ImportWalletBackupFileUsecase(backup, files),
      resumeFileImport: ResumeWalletBackupFileImportUsecase(backup),
      recoverSelectedFile: RecoverSelectedWalletBackupFileUsecase(backup),
    );
  });

  tearDown(() async {
    await cubit.close();
    await states.close();
  });

  test('keeps live backup state and loads protected contents', () async {
    await cubit.loadDataBackup();
    final state = _state();

    states.add(Ok(state));

    expect(cubit.state.walletBackup, same(state));
    expect(cubit.state.contents, isNotNull);
  });

  test('a failed contents load says why instead of going quiet', () async {
    when(
      () => backup.getContents(),
    ).thenAnswer((_) async => const Err(WalletBackupStorageFailure()));

    await cubit.loadContents();

    expect(cubit.state.contentsLoading, isFalse);
    expect(cubit.state.contents, isNull);
    expect(cubit.state.failure, isA<BackupSettingsStorageFailure>());
  });

  test('a reachable server clears the earlier contents failure', () async {
    var attempts = 0;
    when(() => backup.getContents()).thenAnswer((_) async {
      attempts++;
      return attempts == 1
          ? const Err(WalletBackupRemoteUnavailableFailure())
          : const Ok(
              WalletBackupContents(
                labelCount: 0,
                frozenCoinCount: 0,
                walletPreferenceCount: 0,
              ),
            );
    });

    await cubit.loadContents();
    expect(cubit.state.failure, isA<BackupSettingsUnavailableFailure>());

    await cubit.loadContents();

    expect(cubit.state.failure, isNull);
    expect(cubit.state.contents, isNotNull);
  });

  test('a partial recovery retry reports attention, not a crash', () async {
    await cubit.loadDataBackup();
    states.add(Ok(_state(recoveryBlocked: true)));
    when(() => backup.recover()).thenAnswer(
      (_) async => const WalletBackupRecoveryResult(
        status: WalletBackupRecoveryStatus.partiallyRestored,
        restoredCount: 2,
        failedCount: 1,
      ),
    );

    await cubit.retryWalletBackupRecovery();

    expect(
      cubit.state.failure,
      isA<BackupSettingsRecoveryNeedsAttentionFailure>(),
    );
  });

  test('an unreachable server during retry is not called invalid', () async {
    await cubit.loadDataBackup();
    states.add(Ok(_state(recoveryBlocked: true)));
    when(() => backup.recover()).thenAnswer(
      (_) async => const WalletBackupRecoveryResult(
        status: WalletBackupRecoveryStatus.unavailable,
      ),
    );

    await cubit.retryWalletBackupRecovery();

    expect(cubit.state.failure, isA<BackupSettingsUnavailableFailure>());
  });

  test('keeps backup-now busy until publication completes', () async {
    final result = Completer<Result<void, WalletBackupFailure>>();
    when(() => backup.backupNow()).thenAnswer((_) => result.future);

    final pending = cubit.backupWalletNow();
    expect(cubit.state.walletBackupBusy, isTrue);

    result.complete(const Ok(null));
    await pending;
    expect(cubit.state.walletBackupBusy, isFalse);
  });

  test('starting an import clears the preceding export notice', () async {
    final bytes = Uint8List.fromList([4, 5, 6]);
    final export = WalletBackupExport(
      suggestedFilename: 'backup.json',
      bytes: const [1, 2, 3],
    );
    when(
      () => backup.buildExport(
        protection: WalletBackupFileProtection.unencrypted,
        confirmedUnencrypted: true,
      ),
    ).thenAnswer((_) async => Ok(export));
    when(() => files.save(export)).thenAnswer((_) async => const Ok(true));
    when(
      () => files.pick(maximumBytes: any(named: 'maximumBytes')),
    ).thenAnswer((_) async => Ok(bytes));
    when(
      () => backup.compareFile(bytes),
    ).thenAnswer((_) async => Ok(_comparison));

    await cubit.exportBackupFile(
      protection: WalletBackupFileProtection.unencrypted,
      confirmedUnencrypted: true,
    );
    expect(cubit.state.fileExportReady, isTrue);

    await cubit.importBackupFile();

    expect(cubit.state.fileExportReady, isFalse);
    expect(cubit.state.fileComparison, same(_comparison));
  });

  test('does not emit when an import completes after close', () async {
    final picked = Completer<Result<Uint8List?, BackupSettingsFailure>>();
    when(
      () => files.pick(maximumBytes: any(named: 'maximumBytes')),
    ).thenAnswer((_) => picked.future);

    final pending = cubit.importBackupFile();
    await cubit.close();
    picked.complete(const Ok(null));

    await expectLater(pending, completes);
  });

  test(
    'pending retry builds a comparison without opening the file picker',
    () async {
      await cubit.loadDataBackup();
      states.add(Ok(_state(needsAttention: true)));
      final export = WalletBackupExport(
        suggestedFilename: 'backup.json',
        bytes: [1, 2, 3],
      );
      when(
        () => backup.buildExport(
          protection: WalletBackupFileProtection.unencrypted,
          confirmedUnencrypted: true,
        ),
      ).thenAnswer((_) async => Ok(export));
      when(
        () => backup.compareFile(any()),
      ).thenAnswer((_) async => Ok(_comparison));

      await cubit.retryWalletBackupRecovery();

      expect(cubit.state.fileComparison, same(_comparison));
      verifyNever(() => files.pick(maximumBytes: any(named: 'maximumBytes')));
      verifyNever(() => backup.recover());
    },
  );

  test('normal blocked recovery still uses the remote recovery flow', () async {
    await cubit.loadDataBackup();
    states.add(Ok(_state(recoveryBlocked: true)));
    when(() => backup.recover()).thenAnswer(
      (_) async => const WalletBackupRecoveryResult(
        status: WalletBackupRecoveryStatus.restored,
      ),
    );

    await cubit.retryWalletBackupRecovery();

    verify(() => backup.recover()).called(1);
    verifyNever(() => files.pick(maximumBytes: any(named: 'maximumBytes')));
  });

  test('selected recovery passes the same comparison to the facade', () async {
    final bytes = Uint8List.fromList([4, 5, 6]);
    when(
      () => files.pick(maximumBytes: any(named: 'maximumBytes')),
    ).thenAnswer((_) async => Ok(bytes));
    when(
      () => backup.compareFile(bytes),
    ).thenAnswer((_) async => Ok(_comparison));
    when(
      () => backup.recoverComparedFile(
        fileBytes: bytes,
        comparison: _comparison,
        source: WalletBackupImportSource.file,
      ),
    ).thenAnswer(
      (_) async => const WalletBackupRecoveryResult(
        status: WalletBackupRecoveryStatus.restored,
      ),
    );

    await cubit.importBackupFile();
    await cubit.recoverSelectedBackup(WalletBackupImportSource.file);

    verify(
      () => backup.recoverComparedFile(
        fileBytes: bytes,
        comparison: _comparison,
        source: WalletBackupImportSource.file,
      ),
    ).called(1);
  });

  test('stale selection repeats comparison without applying it', () async {
    final bytes = Uint8List.fromList([4, 5, 6]);
    final refreshed = WalletBackupImportComparison(
      situation: WalletBackupImportSituation.serverUnavailable,
      file: _summary,
      server: null,
      differences: const {},
    );
    var comparisons = 0;
    when(
      () => files.pick(maximumBytes: any(named: 'maximumBytes')),
    ).thenAnswer((_) async => Ok(bytes));
    when(() => backup.compareFile(bytes)).thenAnswer((_) async {
      comparisons++;
      return Ok(comparisons == 1 ? _comparison : refreshed);
    });
    when(
      () => backup.recoverComparedFile(
        fileBytes: bytes,
        comparison: _comparison,
        source: WalletBackupImportSource.file,
      ),
    ).thenAnswer(
      (_) async => const WalletBackupRecoveryResult(
        status: WalletBackupRecoveryStatus.comparisonStale,
      ),
    );

    await cubit.importBackupFile();
    await cubit.recoverSelectedBackup(WalletBackupImportSource.file);

    expect(comparisons, 2);
    expect(cubit.state.fileComparison, same(refreshed));
    expect(cubit.state.fileRecoveryResult, isNull);
    verify(
      () => backup.recoverComparedFile(
        fileBytes: bytes,
        comparison: _comparison,
        source: WalletBackupImportSource.file,
      ),
    ).called(1);
  });

  test(
    'cancelling a comparison leaves both backup sources untouched',
    () async {
      final bytes = Uint8List.fromList([4, 5, 6]);
      when(
        () => files.pick(maximumBytes: any(named: 'maximumBytes')),
      ).thenAnswer((_) async => Ok(bytes));
      when(
        () => backup.compareFile(bytes),
      ).thenAnswer((_) async => Ok(_comparison));

      await cubit.importBackupFile();
      cubit.cancelBackupFileImport();

      expect(cubit.state.fileComparison, isNull);
      verifyNever(
        () => backup.recoverComparedFile(
          fileBytes: bytes,
          comparison: _comparison,
          source: WalletBackupImportSource.file,
        ),
      );
      verifyNever(() => backup.backupNow());
    },
  );
}

WalletBackupState _state({
  bool recoveryBlocked = false,
  bool needsAttention = false,
}) => WalletBackupState(
  enabled: true,
  localRevision: needsAttention ? 1 : 0,
  uploadedRevision: 0,
  lastSucceededAt: null,
  unsupportedVersion: null,
  recoveryState: needsAttention
      ? WalletBackupRecoveryState.needsAttention
      : recoveryBlocked
      ? WalletBackupRecoveryState.applying
      : WalletBackupRecoveryState.idle,
  customServerUrl: null,
);

const _summary = WalletBackupSnapshotSummary(
  createdAt: 1,
  walletCount: 0,
  nostrIdentityCount: 0,
  externalWalletCount: 0,
  labelCount: 0,
  frozenOutpointCount: 0,
  walletPreferenceCount: 0,
);

final _comparison = WalletBackupImportComparison(
  situation: WalletBackupImportSituation.noServerBackup,
  file: _summary,
  server: null,
  differences: const {},
);
