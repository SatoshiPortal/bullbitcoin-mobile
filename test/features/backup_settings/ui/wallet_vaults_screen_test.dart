import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/backup_wallet_now_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/delete_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/export_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/fetch_remote_wallet_backup_contents_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_wallet_backup_contents_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/import_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/retry_wallet_backup_recovery_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/set_wallet_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/set_wallet_backup_server_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/watch_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/wallet_vaults_screen.dart';
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

const _vault = WalletBackupVaultSummary(
  walletRef: 'vault-1',
  label: 'Everyday Vault',
  status: 'active',
  network: Network.bitcoinMainnet,
  lineageId: 'lineage-a',
  vaultGeneration: 2,
  descriptor: 'tr(NUMS,{pk(A),multi_a(2,B,C)})#abcd1234',
  birthHeight: 887204,
  recoveryPackage: '{"fake":true}',
);

const _localContents = WalletBackupContents(
  vaults: [_vault],
  labelCount: 0,
  frozenCoinCount: 0,
  walletPreferenceCount: 0,
);

void main() {
  late _MockWalletBackupFacade backup;
  late StreamController<Result<WalletBackupState, WalletBackupFailure>> states;

  setUp(() async {
    await locator.reset();
    backup = _MockWalletBackupFacade();
    states = StreamController.broadcast(sync: true);
    when(() => backup.watchState()).thenAnswer((_) => states.stream);
    when(
      () => backup.getContents(),
    ).thenAnswer((_) async => const Ok(_localContents));
    when(
      () => backup.fetchRemoteContents(),
    ).thenAnswer((_) async => const Ok(null));
    final files = _MockWalletBackupFileRepository();
    locator.registerFactory<BackupSettingsCubit>(
      () => BackupSettingsCubit(
        watchWalletBackup: WatchWalletBackupUsecase(backup),
        setWalletBackupEnabled: SetWalletBackupEnabledUsecase(backup),
        setWalletBackupServer: SetWalletBackupServerUsecase(backup),
        backupWalletNow: BackupWalletNowUsecase(backup),
        deleteWalletBackup: DeleteWalletBackupUsecase(backup),
        getContents: GetWalletBackupContentsUsecase(backup),
        fetchRemoteContents: FetchRemoteWalletBackupContentsUsecase(backup),
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

  Future<void> pump(
    WidgetTester tester, {
    WalletBackupContents? contents,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: WalletVaultsScreen(contents: contents),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists the vaults on this device and reveals the descriptor', (
    tester,
  ) async {
    await pump(tester, contents: _localContents);

    expect(find.text('Everyday Vault'), findsOneWidget);
    expect(find.textContaining('Generation 2'), findsOneWidget);
    expect(find.textContaining('Birth height 887204'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.textContaining('tr(NUMS'), findsNothing);

    await tester.tap(find.text('Everyday Vault'));
    await tester.pumpAndSettle();

    expect(find.textContaining('tr(NUMS'), findsOneWidget);
    expect(find.text('Copy descriptor'), findsOneWidget);
    expect(find.text('Share recovery package'), findsOneWidget);
    verifyNever(() => backup.fetchRemoteContents());
  });

  testWidgets('the server tab reads the remote backup without applying it', (
    tester,
  ) async {
    await pump(tester, contents: _localContents);

    await tester.tap(find.text('Backup server'));
    await tester.pumpAndSettle();

    verify(() => backup.fetchRemoteContents()).called(1);
    expect(
      find.text('The backup server holds no backup for this seed.'),
      findsOneWidget,
    );
    verifyNever(() => backup.recover());
  });

  testWidgets('loads local contents itself when none are handed in', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Everyday Vault'), findsOneWidget);
    verify(() => backup.getContents()).called(1);
  });
}
