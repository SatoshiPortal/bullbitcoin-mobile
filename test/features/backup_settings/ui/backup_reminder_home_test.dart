import 'package:bb_mobile/features/wallet/ui/widgets/backup_warning_overlay.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/backup_card.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/backup_settings/data/backup_reminder_repository_impl.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_backup_reminders_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_reminder_cubit.dart';
import 'package:bb_mobile/features/backup_settings/public/backup_settings_facade.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_errors.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _WalletBloc extends Mock implements WalletBloc {}

void main() {
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

  Future<void> pump(
    WidgetTester tester,
    Wallet wallet, {
    bool includeHomeWarnings = false,
    bool includeOverlay = false,
  }) async {
    final wallets = _WalletBloc();
    when(() => wallets.state).thenReturn(WalletState(wallets: [wallet]));
    when(() => wallets.stream).thenAnswer((_) => const Stream.empty());
    final content = Scaffold(
      body: Column(
        children: [
          if (includeHomeWarnings) const HomeWarnings(),
          BackupReminderHomeContribution(wallets: [wallet]),
        ],
      ),
    );
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<BackupReminderCubit>.value(value: cubit),
          BlocProvider<WalletBloc>.value(value: wallets),
        ],
        child: MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: includeOverlay ? BackupWarningOverlay(child: content) : content,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'zero backup uses the upstream overlay and card without a replacement dialog',
    (tester) async {
      final loc = AppLocalizationsEn();
      await pump(
        tester,
        _wallet(),
        includeHomeWarnings: true,
        includeOverlay: true,
      );
      expect(find.text(loc.backupWarningTitle), findsOneWidget);
      expect(find.text(loc.backupWarningDescription), findsOneWidget);
      expect(find.byType(BackupCard), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    },
  );

  testWidgets(
    'reminder disable leaves the production zero-backup warning intact',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'backup_reminders_dismiss_forever': true,
      });
      await pump(
        tester,
        _wallet(),
        includeHomeWarnings: true,
        includeOverlay: true,
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(BackupCard), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().backupWarningTitle),
        findsOneWidget,
      );
    },
  );

  testWidgets('cycle snooze is persisted by the reminder action', (
    tester,
  ) async {
    await pump(
      tester,
      _wallet(physical: DateTime.now().subtract(const Duration(days: 400))),
      includeOverlay: true,
    );
    expect(find.text('TEST YOUR PHYSICAL BACKUP'), findsOneWidget);
    expect(find.text(AppLocalizationsEn().backupWarningTitle), findsNothing);
    final before = DateTime.now().add(const Duration(days: 365));
    await tester.tap(find.text('REMIND ME IN 365 DAYS'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    final millis = (await SharedPreferences.getInstance()).getInt(
      'backup_reminders_physical_test_snooze_until',
    );
    expect(millis, greaterThanOrEqualTo(before.millisecondsSinceEpoch));
  });
}

Wallet _wallet({int sats = 1, DateTime? physical}) => Wallet(
  origin: 'default',
  network: Network.bitcoinMainnet,
  isDefault: true,
  signers: [
    WalletSigner.single(
      masterFingerprint: 'deadbeef',
      xpubFingerprint: 'cafebabe',
      xpub: 'xpub',
      signer: SignerEntity.local,
      signerDevice: null,
    ),
  ],
  scriptType: ScriptType.bip84,
  publicDescriptor: 'wpkh(xpub/<0;1>/*)',
  balanceSat: BigInt.from(sats),
  latestPhysicalBackup: physical,
  isPhysicalBackupTested: physical != null,
);
