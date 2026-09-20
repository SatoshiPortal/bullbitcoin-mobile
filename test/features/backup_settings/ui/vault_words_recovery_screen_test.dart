import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vaults_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_recovery_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/vault_words_recovery_screen.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../vault_recovery_fixture.dart';
import '../../wallet_backup/backup_snapshot_fixture.dart';

class _Backups extends Mock implements WalletBackupFacade {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.flutterplaza.no_screenshot_methods');
  final loc = AppLocalizationsEn();
  late _Backups backups;
  late VaultRecoveryCubit cubit;
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => true);
    backups = _Backups();
    cubit = VaultRecoveryCubit(RecoverVaultsUsecase(backups));
  });
  tearDown(() async {
    await cubit.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  for (final partial in [true, false]) {
    testWidgets(
      'entered words recover vaults only; partial=$partial never announces false success',
      (tester) async {
        var completed = 0;
        final result = vaultRecoveryFixture(partial: partial);
        when(
          () => backups.recoverVaults(
            words: backupFixtureWords,
            abandoned: any(named: 'abandoned'),
          ),
        ).thenAnswer((_) async => Ok(result));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider.value(
              value: cubit,
              child: Scaffold(
                body: VaultWordsRecoveryScreen(onRecovered: (_) => completed++),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        verifyZeroInteractions(backups);
        final input = tester.widget<MnemonicWidget>(
          find.byType(MnemonicWidget),
        );
        expect(input.allowPassphrase, isFalse);
        expect(input.allowLabel, isFalse);
        expect(input.allowMultipleMnemonicLength, isFalse);
        input.onSubmit((
          words: backupFixtureWords.split(' '),
          label: '',
          passphrase: '',
          language: bip39.Language.english,
        ));
        await tester.pumpAndSettle();
        expect(find.text('Family vault'), findsOneWidget);
        expect(
          find.text(loc.vaultRecoveryIncomplete),
          partial ? findsOneWidget : findsNothing,
        );
        expect(
          find.text(loc.vaultRecoveryOpenVault),
          partial ? findsNothing : findsOneWidget,
        );
        expect(completed, partial ? 0 : 1);
        verify(
          () => backups.recoverVaults(
            words: backupFixtureWords,
            abandoned: any(named: 'abandoned'),
          ),
        ).called(1);
        verifyNoMoreInteractions(backups);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
