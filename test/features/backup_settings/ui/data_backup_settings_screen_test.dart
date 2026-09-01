import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/themes/app_theme.dart';
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
import 'package:bb_mobile/features/backup_settings/ui/screens/backup_settings_screen.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockWalletBackupFacade extends Mock implements WalletBackupFacade {}

class _MockWalletBackupFileRepository extends Mock
    implements WalletBackupFileRepository {}

void main() {
  late _MockWalletBackupFacade backup;
  late _MockWalletBackupFileRepository files;
  late StreamController<Result<WalletBackupState, WalletBackupFailure>> states;

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() async {
    await locator.reset();
    backup = _MockWalletBackupFacade();
    files = _MockWalletBackupFileRepository();
    states = StreamController.broadcast(sync: true);
    when(() => backup.watchState()).thenAnswer((_) => states.stream);
    when(() => backup.getContents()).thenAnswer(
      (_) async => const Ok(
        WalletBackupContents(
          labelCount: 2,
          frozenCoinCount: 1,
          walletPreferenceCount: 3,
        ),
      ),
    );
    locator.registerFactory<BackupSettingsCubit>(
      () => BackupSettingsCubit(
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
      ),
    );
  });

  tearDown(() async {
    await states.close();
    await locator.reset();
  });

  testWidgets('keeps money recovery controls out and orders data controls', (
    tester,
  ) async {
    await _pump(tester);
    states.add(_backupState());
    await tester.pump();

    final labels = [
      'Bull backup',
      'Protected wallet data',
      'Manual data backup',
      'Data exports',
      'Advanced',
    ];
    final positions = [
      for (final label in labels) tester.getTopLeft(find.text(label)).dy,
    ];
    expect(positions, orderedEquals([...positions]..sort()));
    expect(find.text('Automatic Bull backup'), findsOneWidget);
    expect(find.text('Back up now'), findsOneWidget);
    expect(find.text('Export encrypted'), findsOneWidget);
    expect(find.text('Export unencrypted'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    expect(find.text('Backup server'), findsOneWidget);
    expect(find.text('Delete backup'), findsOneWidget);
    expect(find.textContaining('never contains seed phrases'), findsOneWidget);
    expect(find.text('Physical backup'), findsNothing);
    expect(find.text('Encrypted vault'), findsNothing);
  });

  testWidgets('shows exact file and server counts before whole-backup choice', (
    tester,
  ) async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    when(
      () => files.pick(maximumBytes: any(named: 'maximumBytes')),
    ).thenAnswer((_) async => Ok(bytes));
    when(() => backup.compareFile(bytes)).thenAnswer(
      (_) async => Ok(
        WalletBackupImportComparison(
          situation: WalletBackupImportSituation.different,
          file: const WalletBackupSnapshotSummary(
            createdAt: 1,
            walletCount: 4,
            nostrIdentityCount: 2,
            externalWalletCount: 1,
            labelCount: 3,
            frozenOutpointCount: 5,
            walletPreferenceCount: 7,
          ),
          server: const WalletBackupSnapshotSummary(
            createdAt: 2,
            walletCount: 6,
            nostrIdentityCount: 1,
            externalWalletCount: 2,
            labelCount: 8,
            frozenOutpointCount: 13,
            walletPreferenceCount: 21,
          ),
          serverCiphertextBytes: Uint8List.fromList([9, 8, 7]),
          comparedServerGeneration: 2,
          comparedServerEtag: 'server-etag',
          differences: const {WalletBackupDifference.protectedData},
        ),
      ),
    );

    await _pump(tester);
    states.add(_backupState());
    await tester.pump();
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();

    expect(
      find.text('3 labels, 5 frozen coins, 7 wallet preferences'),
      findsOneWidget,
    );
    expect(
      find.text('8 labels, 13 frozen coins, 21 wallet preferences'),
      findsOneWidget,
    );
    expect(find.text('Use imported backup'), findsOneWidget);
    expect(find.text('Use server backup'), findsOneWidget);
  });

  testWidgets('unavailable server still permits local file recovery', (
    tester,
  ) async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    when(
      () => files.pick(maximumBytes: any(named: 'maximumBytes')),
    ).thenAnswer((_) async => Ok(bytes));
    when(() => backup.compareFile(bytes)).thenAnswer(
      (_) async => Ok(
        WalletBackupImportComparison(
          situation: WalletBackupImportSituation.serverUnavailable,
          file: WalletBackupSnapshotSummary(
            createdAt: 1,
            walletCount: 1,
            nostrIdentityCount: 1,
            externalWalletCount: 0,
            labelCount: 0,
            frozenOutpointCount: 0,
            walletPreferenceCount: 0,
          ),
          server: null,
          differences: {},
        ),
      ),
    );

    await _pump(tester);
    states.add(_backupState());
    await tester.pump();
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('You can still use this file now'),
      findsOneWidget,
    );
    expect(find.text('Use imported backup'), findsOneWidget);
  });

  testWidgets('shows pending reconciliation without offering Backup Now', (
    tester,
  ) async {
    await _pump(tester);
    states.add(
      Ok(
        WalletBackupState(
          enabled: true,
          localRevision: 1,
          uploadedRevision: 0,
          lastSucceededAt: null,
          unsupportedVersion: null,
          recoveryState: WalletBackupRecoveryState.needsAttention,
          customServerUrl: null,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Imported backup is on this device.'), findsOneWidget);
    expect(find.text('Compare with server to finish'), findsOneWidget);
    expect(find.text('Back up now'), findsNothing);
  });

  testWidgets('unpublished local changes never read as a finished backup', (
    tester,
  ) async {
    await _pump(tester);
    states.add(
      Ok(
        WalletBackupState(
          enabled: true,
          localRevision: 3,
          uploadedRevision: 2,
          lastSucceededAt: 1,
          unsupportedVersion: null,
          customServerUrl: null,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Backup pending'), findsOneWidget);
    expect(find.textContaining('Last backup:'), findsNothing);
  });
}

Ok<WalletBackupState, WalletBackupFailure> _backupState() => Ok(
  WalletBackupState(
    enabled: true,
    localRevision: 0,
    uploadedRevision: 0,
    lastSucceededAt: 1,
    unsupportedVersion: null,
    customServerUrl: null,
  ),
);

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: const DataBackupSettingsScreen(),
    ),
  );
  await tester.pump();
}
