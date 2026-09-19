import 'dart:async';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vaults_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_recovery_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/vault_recovery_screen.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Backups extends Mock implements WalletBackupFacade {}

void main() {
  testWidgets(
    'manual recovery stays usable while discovery waits and when there is no local credential',
    (tester) async {
      final backups = _Backups();
      final pending =
          Completer<Result<VaultBackupRecovery?, WalletBackupFailure>>();
      when(
        () => backups.recoverVaults(
          words: null,
          abandoned: any(named: 'abandoned'),
        ),
      ).thenAnswer((_) => pending.future);
      final cubit = VaultRecoveryCubit(RecoverVaultsUsecase(backups));
      addTearDown(cubit.close);
      unawaited(cubit.search());
      var descriptor = 0, words = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: VaultRecoveryScreen(
              onDescriptor: () => descriptor++,
              onWords: () => words++,
              onRecovered: (_) => fail('missing credential cannot recover'),
            ),
          ),
        ),
      );
      final loc = AppLocalizationsEn();
      expect(find.byType(SettingsEntryItem), findsNWidgets(2));
      await tester.tap(find.text(loc.vaultRecoveryDescriptorEntry));
      await tester.tap(find.text(loc.dataBackupRecoverWithWords));
      expect(descriptor, 1);
      expect(words, 1);
      pending.complete(const Err(WalletBackupCredentialFailure()));
      await tester.pumpAndSettle();
      expect(find.text(loc.vaultRecoveryNoCredential), findsOneWidget);
      expect(find.byType(SettingsEntryItem), findsNWidgets(2));
      expect(find.text(loc.vaultBackupComingSoon), findsNothing);
    },
  );
}
