import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:primitives/primitives.dart' show Err, Ok;
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/backup_settings/domain/read_backup_status_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_backup_reminders_usecase.dart';
import 'package:bb_mobile/features/backup_settings/data/backup_reminder_repository_impl.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart' as rb;
import '../reminder_fixture.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_reminder_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/backup_settings_screen.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart' show BullSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Wallets extends Mock implements GetWalletsUsecase {}

class _Settings extends Mock implements SettingsCubit {}

class _SettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late _Wallets lookup;
  late BackupReminderCubit reminders;
  late Wallet wallet;
  late GoRouter router;
  late _Settings settings;
  Object? openedOptions;
  late rb.BackupStatus encryptedStatus;

  setUp(() async {
    await locator.reset();
    SharedPreferences.setMockInitialValues({});
    openedOptions = null;
    wallet = reminderWallet().copyWith(isHidden: true);
    encryptedStatus = const rb.BackupStatus();
    lookup = _Wallets();
    settings = _Settings();
    when(() => settings.state).thenReturn(const SettingsState());
    when(() => settings.stream).thenAnswer((_) => const Stream.empty());
    when(
      () => lookup.execute(
        onlyDefaults: true,
        onlyBitcoin: true,
        includeHidden: true,
      ),
    ).thenAnswer((_) async => Ok([wallet]));
    final preferences = _SettingsRepository();
    when(preferences.fetch).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.btc,
        currencyCode: 'CAD',
      ),
    );
    locator.registerFactory(
      () => BackupSettingsCubit(
        ReadBackupStatusUsecase(lookup, preferences, (context) async {
          expect(context.fingerprint.hex, wallet.masterFingerprint);
          expect(context.network, rb.BitcoinNetwork.mainnet);
          return Ok(encryptedStatus);
        }),
      ),
    );
    final repository = BackupReminderRepositoryImpl();
    reminders = BackupReminderCubit(
      loadPreferences: LoadBackupReminderPreferencesUsecase(repository),
      selectReminder: SelectBackupReminderUsecase(
        repository,
        (_) async => Ok(encryptedStatus),
      ),
      dismissReminder: DismissBackupReminderUsecase(repository),
      setDisabled: SetBackupRemindersDisabledUsecase(repository),
    );
    await reminders.loadPreferences();
    router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const BackupSettingsScreen()),
        GoRoute(
          path: '/options',
          name: BackupSettingsSubroute.backupOptions.name,
          builder: (context, state) {
            openedOptions = state.extra;
            return Scaffold(
              body: TextButton(
                onPressed: () => context.pop(true),
                child: const Text('Return without testing'),
              ),
            );
          },
        ),
      ],
    );
  });
  tearDown(() async {
    router.dispose();
    await reminders.close();
    await locator.reset();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<BackupReminderCubit>.value(value: reminders),
          BlocProvider<SettingsCubit>.value(value: settings),
        ],
        child: MaterialApp.router(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: [
            ...AppLocalizations.localizationsDelegates,
            ...rb.RecoverBullFeature.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'untested wallet shows its warning without a nonexistent vault key',
    (tester) async {
      await pump(tester);
      expect(find.text('Wallet Recovery (money backup)'), findsOneWidget);
      expect(find.text('Back up your wallet'), findsOneWidget);
      expect(find.text('START BACKUP'), findsOneWidget);
      expect(find.byIcon(Icons.vpn_key_outlined), findsNothing);
      expect(find.byType(BullSwitch), findsOneWidget);
    },
  );

  testWidgets('money backup keeps reminders and removes data destinations', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Data Backup'), findsNothing);
    expect(find.text('Labels'), findsNothing);
    expect(find.text('Transaction History'), findsNothing);
    expect(find.byType(BullSwitch), findsOneWidget);
  });

  testWidgets('creation alone is not presented as a successful test', (
    tester,
  ) async {
    wallet = wallet.copyWith(
      latestEncryptedBackup: DateTime(2026, 2, 3),
      isEncryptedVaultTested: true,
    );
    await pump(tester);
    expect(find.text('Back up your wallet'), findsOneWidget);
    expect(find.textContaining('February 3, 2026'), findsNothing);
    expect(find.byIcon(Icons.vpn_key_outlined), findsOneWidget);
    expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.verified_outlined));
    await tester.pumpAndSettle();
    expect(
      openedOptions,
      isA<BackupOptionsArgs>().having(
        (args) => args.hasEncryptedBackup,
        'encrypted file can be tested',
        isTrue,
      ),
    );
  });

  testWidgets('both actual test dates are displayed', (tester) async {
    wallet = wallet.copyWith(
      latestPhysicalBackup: DateTime(2026, 1, 2, 10),
      isPhysicalBackupTested: true,
      isEncryptedVaultTested: true,
      latestEncryptedBackup: DateTime(2026, 2, 3, 11),
    );
    encryptedStatus = rb.BackupStatus(
      storedAt: DateTime(2026, 1, 1),
      verifiedAt: DateTime(2026, 2, 3, 11),
    );
    await pump(tester);
    expect(find.textContaining('January 2, 2026'), findsOneWidget);
    expect(find.textContaining('February 3, 2026'), findsOneWidget);
    expect(find.text('Back up your wallet'), findsNothing);
  });

  testWidgets('encrypted-only status retains physical-backup guidance', (
    tester,
  ) async {
    wallet = wallet.copyWith(
      latestEncryptedBackup: DateTime(2026, 2, 3),
      isEncryptedVaultTested: true,
    );
    encryptedStatus = rb.BackupStatus(verifiedAt: DateTime(2026, 2, 3));
    await pump(tester);
    expect(find.text('Can you still recover your wallet?'), findsOneWidget);
    expect(find.text('ADD A PHYSICAL BACKUP'), findsOneWidget);
  });

  testWidgets(
    'a successful route return alone does not fabricate a test date',
    (tester) async {
      await pump(tester);
      await tester.tap(find.text('START BACKUP'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Return without testing'));
      await tester.pumpAndSettle();
      expect(find.text('Back up your wallet'), findsOneWidget);
      verify(
        () => lookup.execute(
          onlyDefaults: true,
          onlyBitcoin: true,
          includeHidden: true,
        ),
      ).called(2);
    },
  );

  testWidgets('disable needs confirmation and can be reversed', (tester) async {
    await pump(tester);
    await tester.ensureVisible(find.byType(BullSwitch));
    await tester.tap(find.byType(BullSwitch));
    await tester.pumpAndSettle();
    expect(find.text('Dismiss all backup reminders?'), findsOneWidget);
    final cancel = find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextButton),
        )
        .first;
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(reminders.state.disabled, isFalse);
    await tester.tap(find.byType(BullSwitch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dismiss forever'));
    await tester.pumpAndSettle();
    expect(reminders.state.disabled, isTrue);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'backup_reminders_dismiss_forever',
      ),
      isTrue,
    );
    await tester.tap(find.byType(BullSwitch));
    await tester.pumpAndSettle();
    expect(reminders.state.disabled, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('missing status offers retry instead of untested claims', (
    tester,
  ) async {
    when(
      () => lookup.execute(
        onlyDefaults: true,
        onlyBitcoin: true,
        includeHidden: true,
      ),
    ).thenAnswer((_) async => Err(WalletStorageFailure('unavailable')));
    await pump(tester);
    expect(find.text('Back up your wallet'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    when(
      () => lookup.execute(
        onlyDefaults: true,
        onlyBitcoin: true,
        includeHidden: true,
      ),
    ).thenAnswer((_) async => Ok([wallet]));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Back up your wallet'), findsOneWidget);
  });
}
