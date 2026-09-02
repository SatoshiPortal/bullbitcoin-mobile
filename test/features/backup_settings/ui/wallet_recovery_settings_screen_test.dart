import 'dart:async';

import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/backup_reminder_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_wallet_recovery_status_usecase.dart';
import 'package:bb_mobile/features/backup_settings/data/backup_reminder_repository_impl.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_backup_reminders_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_reminder_cubit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/wallet_recovery_settings_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/wallet_recovery_settings_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late _MockWalletRepository wallets;
  late _MockSettingsRepository settings;

  Future<
    List<({DateTime? latestEncryptedBackup, DateTime? latestPhysicalBackup})>
  >
  loadStatus() => wallets.getDefaultBitcoinWalletBackupStatuses(
    environment: Environment.mainnet,
  );

  setUp(() async {
    await locator.reset();
    SharedPreferences.setMockInitialValues({});
    wallets = _MockWalletRepository();
    settings = _MockSettingsRepository();
    when(settings.fetch).thenAnswer((_) async => _settings);
    locator.registerFactory(
      () => WalletRecoverySettingsCubit(
        GetWalletRecoveryStatusUsecase(
          () async => (await settings.fetch()).environment,
          (_) => loadStatus(),
        ),
      ),
    );
  });

  tearDown(locator.reset);

  testWidgets('does not flash the urgent hero while recovery status loads', (
    tester,
  ) async {
    final statuses =
        Completer<
          List<
            ({DateTime? latestEncryptedBackup, DateTime? latestPhysicalBackup})
          >
        >();
    when(loadStatus).thenAnswer((_) => statuses.future);

    await _pump(tester);

    expect(find.text('Back up your wallet'), findsNothing);
    statuses.complete([_status()]);
    await tester.pumpAndSettle();
    expect(find.text('Back up your wallet'), findsOneWidget);
    expect(find.text('START BACKUP'), findsOneWidget);
  });

  testWidgets('shows a retry state when recovery status cannot be loaded', (
    tester,
  ) async {
    var attempts = 0;
    when(loadStatus).thenAnswer((_) async {
      if (attempts++ == 0) throw Exception('storage unavailable');
      return [_status()];
    });

    await _pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('Back up your wallet'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsNothing);
    expect(find.text('Back up your wallet'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('refreshes recovery status after a backup flow returns', (
    tester,
  ) async {
    var attempts = 0;
    when(loadStatus).thenAnswer(
      (_) async => attempts++ == 0
          ? [_status()]
          : [_status(physical: DateTime.utc(2026, 2, 3))],
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const WalletRecoverySettingsScreen(),
        ),
        GoRoute(
          path: '/backup-options',
          name: BackupSettingsSubroute.backupOptions.name,
          builder: (context, _) => Scaffold(
            body: TextButton(onPressed: context.pop, child: const Text('Done')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpRouter(tester, router);
    await tester.pumpAndSettle();
    await tester.tap(find.text('START BACKUP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    verify(loadStatus).called(2);
    expect(find.text('Tested'), findsOneWidget);
  });

  testWidgets('vault-only posture asks for one physical backup action', (
    tester,
  ) async {
    when(
      loadStatus,
    ).thenAnswer((_) async => [_status(encrypted: DateTime.utc(2026, 1, 2))]);

    await _pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('Tested'), findsOneWidget);
    expect(find.text('ADD A PHYSICAL BACKUP'), findsOneWidget);
  });

  testWidgets('requires confirmation before dismissing reminders forever', (
    tester,
  ) async {
    when(
      loadStatus,
    ).thenAnswer((_) async => [_status(encrypted: DateTime.utc(2026, 1, 2))]);

    await _pump(tester);
    await tester.pumpAndSettle();
    final setting = find.text('Dismiss backup reminders forever');
    await tester.scrollUntilVisible(setting, 200);
    await tester.tap(setting);
    await tester.pumpAndSettle();

    expect(find.text('Dismiss all backup reminders?'), findsOneWidget);
    await tester.tap(find.text('Dismiss forever'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('backup_reminders_dismiss_forever'), isTrue);
  });

  testWidgets('shows a failure when reminder dismissal cannot be saved', (
    tester,
  ) async {
    when(
      loadStatus,
    ).thenAnswer((_) async => [_status(encrypted: DateTime.utc(2026, 1, 2))]);

    await _pump(tester, reminderRepository: _FailingReminderRepository());
    await tester.pumpAndSettle();
    final setting = find.text('Dismiss backup reminders forever');
    await tester.scrollUntilVisible(setting, 200);
    await tester.tap(setting);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dismiss forever'));
    await tester.pump();

    expect(find.text('Oops! Something went wrong'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}

Future<void> _pump(
  WidgetTester tester, {
  BackupReminderRepository? reminderRepository,
}) {
  final reminders = _reminders(
    reminderRepository ?? BackupReminderRepositoryImpl(),
  )..load();
  return tester.pumpWidget(
    BlocProvider.value(
      value: reminders,
      child: MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const WalletRecoverySettingsScreen(),
      ),
    ),
  );
}

Future<void> _pumpRouter(WidgetTester tester, GoRouter router) =>
    tester.pumpWidget(
      BlocProvider(
        create: (_) => _reminders(BackupReminderRepositoryImpl())..load(),
        child: MaterialApp.router(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );

BackupReminderCubit _reminders(BackupReminderRepository repository) =>
    BackupReminderCubit(
      LoadBackupReminderPreferencesUsecase(repository),
      SelectBackupReminderUsecase(repository),
      DismissBackupReminderUsecase(repository),
      SetBackupRemindersDismissedUsecase(repository),
    );

({DateTime? latestEncryptedBackup, DateTime? latestPhysicalBackup}) _status({
  DateTime? physical,
  DateTime? encrypted,
}) => (latestPhysicalBackup: physical, latestEncryptedBackup: encrypted);

const _settings = SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'USD',
);

final class _FailingReminderRepository implements BackupReminderRepository {
  @override
  Future<Result<BackupReminderPreferences, BackupSettingsFailure>>
  load() async => const Ok(BackupReminderPreferences());

  @override
  Future<Result<void, BackupSettingsFailure>> setDismissForever(
    bool value,
  ) async => const Err(BackupSettingsUnexpectedFailure());

  @override
  Future<Result<void, BackupSettingsFailure>>
  dismissLargeBalanceWarning() async => const Ok(null);

  @override
  Future<Result<void, BackupSettingsFailure>> snooze(
    BackupReminder reminder,
    DateTime until,
  ) async => const Ok(null);
}
