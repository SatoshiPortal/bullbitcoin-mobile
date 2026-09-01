import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/backup_settings/data/backup_reminder_repository_impl.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/backup_reminder_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_backup_reminders_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_reminder_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/backup_reminder_listener.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows one non-dismissible modal and opens its primary action', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final cubit = _cubit(BackupReminderRepositoryImpl());
    var actionCount = 0;

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: BackupReminderListener(
            onAction: (_) => actionCount++,
            child: const SizedBox(),
          ),
        ),
      ),
    );
    await cubit.evaluate([_wallet()]);
    await tester.pumpAndSettle();

    expect(find.text('BACKUP YOUR WALLET NOW'), findsOneWidget);
    expect(
      find.text('Without a backup, you will lose access to your bitcoin if:'),
      findsOneWidget,
    );
    expect(find.text('You lose your phone'), findsOneWidget);
    expect(
      find.text('There is no way to recover your wallet without a backup.'),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('BACKUP YOUR WALLET NOW'), findsOneWidget);

    await tester.tap(find.text('YES'));
    await tester.pumpAndSettle();
    expect(actionCount, 1);

    await cubit.evaluate([_wallet()]);
    await tester.pumpAndSettle();
    expect(find.text('BACKUP YOUR WALLET NOW'), findsNothing);
    await cubit.close();
  });

  testWidgets('reports a failed permanent warning dismissal', (tester) async {
    final cubit = _cubit(_FailingDismissRepository());
    addTearDown(cubit.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: BackupReminderListener(
            onAction: (_) {},
            child: const SizedBox(),
          ),
        ),
      ),
    );

    await cubit.evaluate([
      _wallet(
        balance: SelectBackupReminderUsecase.largeBalanceThresholdSats,
        latestEncryptedBackup: DateTime.now(),
      ),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('DISMISS WARNING — I UNDERSTAND THE RISKS'));
    await tester.pumpAndSettle();

    expect(find.text('Oops! Something went wrong'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  final now = DateTime.utc(2026, 8, 29);
  for (final testCase in [
    (
      name: 'large-balance vault-only warning',
      wallet: _wallet(balance: 10000000, latestEncryptedBackup: now),
      title: 'YOUR ENCRYPTED VAULT IS YOUR ONLY BACKUP',
      body:
          'Your encrypted vault is tested, but recovery still depends on the backup server being available. Add and test a physical backup for independent recovery.',
      primary: 'ADD A PHYSICAL BACKUP',
      secondary: 'DISMISS WARNING — I UNDERSTAND THE RISKS',
      initialPreferences: const <String, Object>{},
    ),
    (
      name: '180-day add-physical reminder',
      wallet: _wallet(
        latestEncryptedBackup: now.subtract(const Duration(days: 180)),
      ),
      title: 'ADD A PHYSICAL BACKUP',
      body:
          'Your tested encrypted vault still depends on the backup server. Add and test a physical backup so you can recover without it.',
      primary: 'ADD A PHYSICAL BACKUP',
      secondary: 'REMIND ME IN 180 DAYS',
      initialPreferences: const <String, Object>{},
    ),
    (
      name: '365-day physical test reminder',
      wallet: _wallet(
        latestPhysicalBackup: now.subtract(const Duration(days: 365)),
      ),
      title: 'TEST YOUR PHYSICAL BACKUP',
      body:
          'Your last successful physical backup test was over a year ago. Test it end to end to make sure it can still recover your wallet.',
      primary: 'TEST PHYSICAL BACKUP',
      secondary: 'REMIND ME IN 365 DAYS',
      initialPreferences: const <String, Object>{},
    ),
    (
      name: '366-day encrypted-vault test reminder',
      wallet: _wallet(
        latestEncryptedBackup: now.subtract(const Duration(days: 366)),
        latestPhysicalBackup: now.subtract(const Duration(days: 366)),
      ),
      title: 'TEST YOUR ENCRYPTED VAULT',
      body:
          'Your last successful encrypted vault test was over a year ago. Test it end to end to make sure it can still recover your wallet.',
      primary: 'TEST ENCRYPTED VAULT',
      secondary: 'REMIND ME IN 366 DAYS',
      initialPreferences: <String, Object>{
        'backup_reminders_physical_test_snooze_until': now
            .add(const Duration(days: 1))
            .millisecondsSinceEpoch,
      },
    ),
  ]) {
    testWidgets('shows exact ${testCase.name} copy', (tester) async {
      SharedPreferences.setMockInitialValues(testCase.initialPreferences);
      final cubit = _cubit(BackupReminderRepositoryImpl(), now: () => now);
      addTearDown(cubit.close);

      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: BackupReminderListener(
              onAction: (_) {},
              child: const SizedBox(),
            ),
          ),
        ),
      );

      await cubit.evaluate([testCase.wallet]);
      await tester.pumpAndSettle();

      expect(find.text(testCase.title), findsAtLeastNWidgets(1));
      expect(find.text(testCase.body), findsOneWidget);
      expect(find.text(testCase.primary), findsAtLeastNWidgets(1));
      expect(find.text(testCase.secondary), findsOneWidget);
      await tester.tap(find.text(testCase.secondary));
      await tester.pumpAndSettle();
    });
  }
}

BackupReminderCubit _cubit(
  BackupReminderRepository repository, {
  DateTime Function()? now,
}) => BackupReminderCubit(
  LoadBackupReminderPreferencesUsecase(repository),
  SelectBackupReminderUsecase(repository, now: now),
  DismissBackupReminderUsecase(repository, now: now),
  SetBackupRemindersDismissedUsecase(repository),
);

Wallet _wallet({
  int balance = 1,
  DateTime? latestEncryptedBackup,
  DateTime? latestPhysicalBackup,
}) => Wallet(
  origin: 'default-bitcoin',
  network: Network.bitcoinMainnet,
  isDefault: true,
  xpubFingerprint: '12345678',
  scriptType: ScriptType.bip84,
  xpub: 'xpub',
  externalPublicDescriptor: 'wpkh(xpub/0/*)',
  internalPublicDescriptor: 'wpkh(xpub/1/*)',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(balance),
  latestEncryptedBackup: latestEncryptedBackup,
  latestPhysicalBackup: latestPhysicalBackup,
);

final class _FailingDismissRepository implements BackupReminderRepository {
  @override
  Future<Result<BackupReminderPreferences, BackupSettingsFailure>>
  load() async => const Ok(BackupReminderPreferences());

  @override
  Future<Result<void, BackupSettingsFailure>>
  dismissLargeBalanceWarning() async =>
      const Err(BackupSettingsUnexpectedFailure());

  @override
  Future<Result<void, BackupSettingsFailure>> setDismissForever(
    bool value,
  ) async => const Ok(null);

  @override
  Future<Result<void, BackupSettingsFailure>> snooze(
    BackupReminder reminder,
    DateTime until,
  ) async => const Ok(null);
}
