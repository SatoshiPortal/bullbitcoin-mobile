import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_data_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_recovery_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/data_backup_recovery_screen.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_ciphertext.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../wallet_backup/backup_snapshot_fixture.dart';

class _Inspect extends Mock implements InspectDataBackupUsecase {}

class _Recover extends Mock implements RecoverDataBackupUsecase {}

void main() {
  final loc = AppLocalizationsEn();
  final credential = BackupCredential.fromWords(backupFixtureWords);
  final inspection = WalletBackupInspection(
    identity: credential.serverPublicKey,
    head: WalletBackupRemoteHead(
      generation: 1,
      etag: 'a' * 64,
      ciphertext: WalletBackupCiphertext(List.filled(64, 1)),
    ),
    snapshot: backupSnapshotFixture(credential),
  );
  late _Inspect inspect;
  late _Recover recover;
  late DataBackupRecoveryCubit cubit;
  late int completed;
  setUp(() {
    inspect = _Inspect();
    recover = _Recover();
    cubit = DataBackupRecoveryCubit(inspect, recover);
    completed = 0;
    when(() => inspect.execute()).thenAnswer((_) async => Ok(inspection));
  });
  tearDown(() => cubit.close());
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider.value(
        value: cubit,
        child: DataBackupRecoveryScreen(
          onRecovered: (source, result) {
            expect(source, same(inspection));
            expect(result.complete, isTrue);
            completed++;
          },
        ),
      ),
    ),
  );
  testWidgets('current-wallet inspection waits for explicit recovery', (
    tester,
  ) async {
    await cubit.inspect();
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text(loc.dataBackupSourceServer), findsOneWidget);
    expect(find.text('Savings'), findsOneWidget);
    expect(find.text(loc.dataBackupRecover), findsOneWidget);
    verifyZeroInteractions(recover);
    expect(completed, 0);
  });
  testWidgets('inspection failure is visible and has a read-only retry', (
    tester,
  ) async {
    when(
      () => inspect.execute(),
    ).thenAnswer((_) async => const Err(BackupSettingsNetworkFailure()));
    await cubit.inspect();
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text(loc.dataBackupNetworkFailure), findsOneWidget);
    when(() => inspect.execute()).thenAnswer((_) async => Ok(inspection));
    await tester.tap(find.text(loc.retry));
    await tester.pumpAndSettle();
    expect(find.text(loc.dataBackupSourceServer), findsOneWidget);
    verifyZeroInteractions(recover);
  });
  testWidgets(
    'partial results stay visible and only full recovery announces success',
    (tester) async {
      var attempt = 0;
      when(
        () => recover.execute(
          inspection,
          confirmed: true,
          enableAfterRecovery: false,
        ),
      ).thenAnswer(
        (_) async => Ok(
          WalletBackupRecovery(
            wallets: WalletInventoryRecovery(
              walletReferences: {'source-wallet': 'actual-target'},
              failedReferences: [],
            ),
            publicRecordsRestored: true,
            metadataRestored: ++attempt > 1,
          ),
        ),
      );
      await cubit.inspect();
      await pump(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text(loc.dataBackupRecover));
      await tester.pumpAndSettle();
      expect(find.text(loc.dataBackupRecoveryIncomplete), findsOneWidget);
      expect(find.text('actual-target'), findsOneWidget);
      expect(completed, 0);
      await tester.tap(find.text(loc.retry));
      await tester.pumpAndSettle();
      expect(find.text(loc.dataBackupRecoveryComplete), findsOneWidget);
      expect(find.text(loc.dataBackupRecoveryIncomplete), findsNothing);
      expect(completed, 1);
      verify(() => inspect.execute()).called(1);
    },
  );
}
