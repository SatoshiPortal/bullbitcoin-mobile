import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_data_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_recovery_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/data_backup_words_recovery_screen.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_ciphertext.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../wallet_backup/backup_snapshot_fixture.dart';

class _Backups extends Mock implements WalletBackupFacade {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.flutterplaza.no_screenshot_methods');
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
  late _Backups backups;
  late DataBackupRecoveryCubit cubit;
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => true);
    backups = _Backups();
    when(
      () => backups.inspect(words: backupFixtureWords),
    ).thenAnswer((_) async => Ok(inspection));
    cubit = DataBackupRecoveryCubit(
      InspectDataBackupUsecase(backups),
      RecoverDataBackupUsecase(backups),
    );
  });
  tearDown(() async {
    await cubit.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  for (final confirm in [false, true]) {
    testWidgets(
      'full words recovery inspects once; confirmation=$confirm controls application',
      (tester) async {
        var completed = 0;
        when(
          () => backups.recover(
            inspection,
            words: backupFixtureWords,
            enableAfterRecovery: false,
          ),
        ).thenAnswer(
          (_) async => Ok(
            WalletBackupRecovery(
              wallets: WalletInventoryRecovery(
                walletReferences: {},
                failedReferences: [],
              ),
              publicRecordsRestored: true,
              metadataRestored: true,
            ),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider.value(
              value: cubit,
              child: DataBackupWordsRecoveryScreen(
                onRecovered: (_, _) => completed++,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        verifyZeroInteractions(backups);
        tester.widget<MnemonicWidget>(find.byType(MnemonicWidget)).onSubmit((
          words: backupFixtureWords.split(' '),
          label: '',
          passphrase: '',
          language: bip39.Language.english,
        ));
        await tester.pumpAndSettle();
        verify(() => backups.inspect(words: backupFixtureWords)).called(1);
        verifyNever(
          () => backups.recover(
            inspection,
            words: backupFixtureWords,
            enableAfterRecovery: false,
          ),
        );
        await tester.tap(
          find.widgetWithText(
            TextButton,
            confirm ? loc.dataBackupRecover : loc.cancelButton,
          ),
        );
        await tester.pumpAndSettle();
        if (confirm) {
          verify(
            () => backups.recover(
              inspection,
              words: backupFixtureWords,
              enableAfterRecovery: false,
            ),
          ).called(1);
          expect(find.text(loc.dataBackupRecoveryComplete), findsOneWidget);
        } else {
          verifyNever(
            () => backups.recover(
              inspection,
              words: backupFixtureWords,
              enableAfterRecovery: false,
            ),
          );
          expect(find.byType(MnemonicWidget), findsOneWidget);
        }
        expect(completed, confirm ? 1 : 0);
        verifyNoMoreInteractions(backups);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
