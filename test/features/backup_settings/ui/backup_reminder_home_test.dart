import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/cards/backup_card.dart';
import 'package:bb_mobile/features/backup_settings/data/backup_reminder_repository_impl.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_backup_reminders_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_reminder_cubit.dart';
import 'package:bb_mobile/features/backup_settings/public/backup_settings_facade.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/backup_reminder_setting.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/router.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_facade.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/backup_warning_overlay.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_errors.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:bull_ui/bull_ui.dart' show BullSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../reminder_fixture.dart';

class _WalletBloc extends Mock implements WalletBloc {}

void main() {
  final loc = AppLocalizationsEn();
  final old = DateTime.now().subtract(const Duration(days: 400));
  late BackupReminderCubit cubit;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final repository = BackupReminderRepositoryImpl();
    cubit = BackupReminderCubit(
      loadPreferences: LoadBackupReminderPreferencesUsecase(repository),
      selectReminder: SelectBackupReminderUsecase(repository),
      dismissReminder: DismissBackupReminderUsecase(repository),
      setDisabled: SetBackupRemindersDisabledUsecase(repository),
    );
  });
  tearDown(() => cubit.close());

  Future<GoRouter> pump(
    WidgetTester tester,
    Wallet wallet, {
    bool includeWarnings = false,
    bool includeSetting = false,
    void Function(Object?)? onRecovery,
  }) async {
    final wallets = _WalletBloc();
    when(() => wallets.state).thenReturn(WalletState(wallets: [wallet]));
    when(() => wallets.stream).thenAnswer((_) => const Stream.empty());
    final content = Scaffold(
      body: Column(
        children: [
          if (includeWarnings) const HomeWarnings(),
          if (includeSetting) const BackupReminderSetting(),
          BackupReminderHomeContribution(wallets: [wallet]),
        ],
      ),
    );
    Widget recovery(BuildContext context, GoRouterState state) {
      onRecovery?.call(state.extra);
      return const Scaffold(body: Text('Recovery'));
    }

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              includeWarnings ? BackupWarningOverlay(child: content) : content,
        ),
        GoRoute(
          path: '/physical',
          name: TestWalletBackupFacade.routeName,
          builder: recovery,
        ),
        GoRoute(
          path: RecoverBullRoute.recoverbullFlows.path,
          name: RecoverBullRoute.recoverbullFlows.name,
          builder: recovery,
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<BackupReminderCubit>.value(value: cubit),
          BlocProvider<WalletBloc>.value(value: wallets),
        ],
        child: MaterialApp.router(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  for (final disabled in [false, true]) {
    testWidgets(
      'zero-backup warnings remain visible with reminders disabled=$disabled',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'backup_reminders_dismiss_forever': disabled,
        });
        await pump(tester, reminderWallet(), includeWarnings: true);
        expect(find.text(loc.backupWarningTitle), findsOneWidget);
        expect(find.text(loc.backupWarningDescription), findsOneWidget);
        expect(find.byType(BackupCard), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
      },
    );
  }

  for (final (wallet, label, key, days) in [
    (
      reminderWallet(encrypted: old),
      loc.backupReminderLater180Days,
      'backup_reminders_add_physical_snooze_until',
      180,
    ),
    (
      reminderWallet(physical: old),
      loc.backupReminderLater365Days,
      'backup_reminders_physical_test_snooze_until',
      365,
    ),
    (
      reminderWallet(physical: old, encrypted: old),
      loc.backupReminderLater366Days,
      'backup_reminders_vault_test_snooze_until',
      366,
    ),
  ]) {
    testWidgets('$label closes the dialog and persists the snooze', (
      tester,
    ) async {
      if (days == 366) {
        SharedPreferences.setMockInitialValues({
          'backup_reminders_physical_test_snooze_until': DateTime.now()
              .add(const Duration(days: 1))
              .millisecondsSinceEpoch,
        });
      }
      await pump(tester, wallet);
      final before = DateTime.now().add(Duration(days: days));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).getInt(key),
        greaterThanOrEqualTo(before.millisecondsSinceEpoch),
      );
    });
  }

  testWidgets('large-balance warning persists its one-time dismissal', (
    tester,
  ) async {
    await pump(
      tester,
      reminderWallet(sats: 10000000, encrypted: DateTime.now()),
    );
    expect(find.text(loc.backupReminderLargeBalanceBody), findsOneWidget);
    await tester.tap(find.text(loc.backupReminderDismissRisk));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'backup_reminders_large_balance_dismissed',
      ),
      isTrue,
    );
  });

  for (final (name, wallet, button, expectedFlow) in [
    (
      'large balance',
      reminderWallet(sats: 10000000, encrypted: DateTime.now()),
      loc.backupReminderAddPhysical,
      TestPhysicalBackupFlow.backup,
    ),
    (
      'encrypted only',
      reminderWallet(encrypted: old),
      loc.backupReminderAddPhysical,
      TestPhysicalBackupFlow.backup,
    ),
    (
      'physical test',
      reminderWallet(physical: old),
      loc.backupReminderTestPhysical,
      TestPhysicalBackupFlow.verify,
    ),
    (
      'encrypted test',
      reminderWallet(physical: old, encrypted: old),
      loc.backupReminderTestVault,
      RecoverBullFlow.testVault,
    ),
  ]) {
    testWidgets('$name action opens the matching recovery flow', (
      tester,
    ) async {
      if (expectedFlow == RecoverBullFlow.testVault) {
        SharedPreferences.setMockInitialValues({
          'backup_reminders_physical_test_snooze_until': DateTime.now()
              .add(const Duration(days: 1))
              .millisecondsSinceEpoch,
        });
      }
      Object? extra;
      final router = await pump(
        tester,
        wallet,
        onRecovery: (value) => extra = value,
      );
      await tester.tap(find.widgetWithText(FilledButton, button));
      await tester.pumpAndSettle();
      expect(find.text('Recovery'), findsOneWidget);
      expect(
        router.state.name,
        expectedFlow == RecoverBullFlow.testVault
            ? RecoverBullRoute.recoverbullFlows.name
            : TestWalletBackupFacade.routeName,
      );
      if (expectedFlow == RecoverBullFlow.testVault) {
        final request = extra! as RecoverBullFlowsExtra;
        expect(request.flow, expectedFlow);
        expect(request.returnToCaller, isTrue);
        expect(request.vault, isNull);
      } else {
        expect(extra, expectedFlow);
      }
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Recovery'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });
  }

  testWidgets('disabling requires confirmation and can be reversed', (
    tester,
  ) async {
    await pump(tester, reminderWallet(sats: 0), includeSetting: true);
    await tester.tap(find.byType(BullSwitch));
    await tester.pumpAndSettle();
    expect(
      find.text(loc.backupReminderDismissForeverConfirmTitle),
      findsOneWidget,
    );
    await tester.tap(find.text(loc.cancelButton));
    await tester.pumpAndSettle();
    expect(tester.widget<BullSwitch>(find.byType(BullSwitch)).value, isFalse);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'backup_reminders_dismiss_forever',
      ),
      isNull,
    );

    await tester.tap(find.byType(BullSwitch));
    await tester.pumpAndSettle();
    await tester.tap(find.text(loc.backupReminderDismissForeverConfirm));
    await tester.pumpAndSettle();
    expect(tester.widget<BullSwitch>(find.byType(BullSwitch)).value, isTrue);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'backup_reminders_dismiss_forever',
      ),
      isTrue,
    );

    await tester.tap(find.byType(BullSwitch));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.widget<BullSwitch>(find.byType(BullSwitch)).value, isFalse);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'backup_reminders_dismiss_forever',
      ),
      isFalse,
    );
  });
}
