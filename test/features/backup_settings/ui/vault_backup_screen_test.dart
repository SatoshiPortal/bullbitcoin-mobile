import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/backup_test_status_row.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_backup_status.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_backup_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/vault_backup_screen.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../bullvault/bullvault_test_fixture.dart';

class _Cubit extends Mock implements VaultBackupCubit {}

void main() {
  final loc = AppLocalizationsEn();
  final record = testBullVaultCreateResult(walletId: 'selected').record;
  late _Cubit cubit;
  int dataOpens = 0;
  setUp(() {
    cubit = _Cubit();
    dataOpens = 0;
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.load('selected')).thenAnswer((_) async {});
    when(cubit.checkServer).thenAnswer((_) async {});
  });
  Future<void> pump(WidgetTester tester, VaultBackupState state) async {
    when(() => cubit.state).thenReturn(state);
    await tester.binding.setSurfaceSize(const Size(440, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<VaultBackupCubit>.value(
          key: ValueKey(state),
          value: cubit,
          child: VaultBackupScreen(
            walletId: 'selected',
            onOpenDataBackup: () async {
              dataOpens++;
            },
          ),
        ),
      ),
    );
    await tester.pump();
  }

  VaultBackupStatus data({
    bool words = true,
    bool incomplete = false,
    bool enabled = true,
  }) => VaultBackupStatus(
    record: record,
    control: WalletBackupControl(
      enabled: enabled,
      recoveryIncomplete: incomplete,
    ),
    canRevealWords: words,
    recoveryPackageSource: testBullVaultRecoveryPackageCodec().encode(
      record.recoveryPackage,
    ),
  );

  testWidgets(
    'exactly three future destinations are disabled with no test date',
    (tester) async {
      await pump(tester, VaultBackupLoaded(data()));
      for (final key in ['nostr', 'bitcoin', 'bip138']) {
        final row = find.byKey(ValueKey('vault-future-$key'));
        expect(row, findsOneWidget);
        expect(tester.widget<BackupTestStatusRow>(row).testedAt, isNull);
        expect(
          find.descendant(
            of: row,
            matching: find.text(loc.vaultBackupComingSoon),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: row,
            matching: find.textContaining(loc.backupSettingsTestedOn('')),
          ),
          findsNothing,
        );
      }
      expect(find.text(loc.vaultBackupComingSoon), findsNWidgets(3));
    },
  );
  testWidgets(
    'check uses the current screen action and Data Backup return reloads selected vault',
    (tester) async {
      await pump(tester, VaultBackupLoaded(data()));
      await tester.tap(find.byKey(const ValueKey('vault-check-server')));
      await tester.pump();
      verify(cubit.checkServer).called(1);
      verifyNever(() => cubit.load('selected'));
      await pump(tester, VaultBackupLoaded(data(enabled: false)));
      await tester.tap(find.byKey(const ValueKey('vault-open-data-backup')));
      await tester.pump();
      expect(dataOpens, 1);
      verify(() => cubit.load('selected')).called(1);
    },
  );
  testWidgets(
    'incomplete and action failure stay visible beside honest dates',
    (tester) async {
      await pump(
        tester,
        VaultBackupLoaded(
          data(incomplete: true),
          failure: const BackupSettingsNetworkFailure(),
        ),
      );
      expect(find.text(loc.dataBackupRecoveryIncomplete), findsOneWidget);
      expect(find.text(loc.dataBackupNetworkFailure), findsOneWidget);
      expect(find.text(loc.backupSettingsNotTested), findsNWidgets(2));
      expect(find.text(loc.dataBackupWordsTitle), findsOneWidget);
    },
  );
  testWidgets(
    'foreign vault omits words and disabled backup retains enablement guidance',
    (tester) async {
      await pump(tester, VaultBackupLoaded(data(words: false, enabled: false)));
      expect(find.text(loc.dataBackupWordsTitle), findsNothing);
      expect(find.text(loc.vaultBackupEnableGuidance), findsOneWidget);
    },
  );
  testWidgets('loading failure provides a selected-vault retry', (
    tester,
  ) async {
    await pump(
      tester,
      const VaultBackupFailed(BackupSettingsUnexpectedFailure()),
    );
    await tester.tap(find.text(loc.retry));
    verify(() => cubit.load('selected')).called(1);
  });
}
