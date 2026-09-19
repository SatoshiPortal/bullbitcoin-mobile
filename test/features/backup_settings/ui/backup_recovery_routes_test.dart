import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_data_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vaults_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_recovery_cubit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_recovery_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/vault_words_recovery_screen.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const privacy = MethodChannel('com.flutterplaza.no_screenshot_methods');
  final loc = AppLocalizationsEn();
  late _Backups backups;
  late GoRouter router;
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(privacy, (_) async => true);
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
        GoRoute(
          path: '/bullvault/restore/descriptor',
          name: BullVaultFacade.descriptorRestoreRouteName,
          builder: (_, _) =>
              const Scaffold(body: Text('descriptor destination')),
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
    'the retained restore route reaches both manual destinations without a seed',
    (tester) async {
      await pump(tester);
      expect(find.text(loc.vaultRecoveryNoCredential), findsOneWidget);
      await tester.tap(find.text(loc.vaultRecoveryDescriptorEntry));
      await tester.pumpAndSettle();
      expect(find.text('descriptor destination'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text(loc.dataBackupRecoverWithWords));
      await tester.pumpAndSettle();
      expect(find.byType(VaultWordsRecoveryScreen), findsOneWidget);
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
