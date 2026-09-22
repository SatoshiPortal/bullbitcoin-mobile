import 'package:bb_mobile/features/bullvault/domain/usecases/pick_bullvault_recovery_file_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/restore_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_restore_cubit.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_restore_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/vault_recovery_screen.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_data_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vaults_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_recovery_cubit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_recovery_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/vault_words_recovery_screen.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import '../vault_recovery_fixture.dart';

class _Backups extends Mock implements WalletBackupFacade {}

class _Restore extends Mock implements RestoreBullVaultUsecase {}

class _Pick extends Mock implements PickBullVaultRecoveryFileUsecase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const privacy = MethodChannel('com.flutterplaza.no_screenshot_methods');
  final loc = AppLocalizationsEn();
  late _Backups backups;
  late GoRouter router;
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(privacy, (_) async => true);
    locator.registerFactory(() => BullVaultRestoreCubit(_Restore(), _Pick()));
    backups = _Backups();
    when(
      () => backups.recoverVaults(
        words: null,
        abandoned: any(named: 'abandoned'),
      ),
    ).thenAnswer((_) async => const Err(WalletBackupCredentialFailure()));
    locator.registerFactory(
      () => VaultRecoveryCubit(RecoverVaultsUsecase(backups)),
    );
    locator.registerFactoryParam<
      DataBackupRecoveryCubit,
      WalletBackupInspection?,
      void
    >(
      (inspection, _) => DataBackupRecoveryCubit(
        InspectDataBackupUsecase(backups),
        RecoverDataBackupUsecase(backups),
        inspection: inspection,
      ),
    );
    router = GoRouter(
      initialLocation: '/bullvault/restore',
      routes: [
        ...BackupSettingsRouter.recoveryRoutes(
          onVaultsRecovered: (_) {},
          onDataRecovered: (_, _) {},
        ),
      ],
    );
  });
  tearDown(() async {
    router.dispose();
    await locator.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(privacy, null);
  });
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the recovery page shows both manual inputs without another page or a local seed',
    (tester) async {
      await pump(tester);
      expect(find.text(loc.vaultRecoveryNoCredential), findsOneWidget);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text(loc.vaultRecoveryDescriptorEntry).last);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/bullvault/restore',
      );
      expect(find.byType(VaultRecoveryScreen), findsOneWidget);
      expect(find.byType(BullVaultRestoreScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text(loc.dataBackupWordsTitle).last);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/bullvault/restore',
      );
      expect(find.byType(VaultRecoveryScreen), findsOneWidget);
      expect(find.byType(VaultWordsRecoveryScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      verify(
        () => backups.recoverVaults(
          words: null,
          abandoned: any(named: 'abandoned'),
        ),
      ).called(1);
      verifyNoMoreInteractions(backups);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'opening an already inspected data backup neither refetches nor applies it',
    (tester) async {
      await pump(tester);
      final inspection = vaultRecoveryFixture().inspection;
      router.goNamed(
        BackupSettingsRoute.dataRecovery.name,
        extra: DataBackupRecoveryArgs(
          inspection: inspection,
          enableAfterRecovery: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(loc.dataBackupSourceServer), findsOneWidget);
      verify(
        () => backups.recoverVaults(
          words: null,
          abandoned: any(named: 'abandoned'),
        ),
      ).called(1);
      verifyNoMoreInteractions(backups);
    },
  );
}
