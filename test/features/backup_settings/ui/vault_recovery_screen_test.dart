import 'dart:async';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vaults_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_recovery_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/vault_recovery_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/vault_words_recovery_screen.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Backups extends Mock implements WalletBackupFacade {}

void main() {
  testWidgets(
    'manual choice abandons discovery and cannot dispose a native restore',
    (tester) async {
      const privacy = MethodChannel('com.flutterplaza.no_screenshot_methods');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(privacy, (_) async => true);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(privacy, null),
      );
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
      ValueChanged<bool>? nativeRestoring;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: VaultRecoveryScreen(
              descriptorBuilder: (onRestoringChanged) {
                nativeRestoring = onRestoringChanged;
                return const Center(child: Text('descriptor input'));
              },
              onRecovered: (_) => fail('missing credential cannot recover'),
            ),
          ),
        ),
      );
      final loc = AppLocalizationsEn();
      final selector = find.byWidgetPredicate(
        (widget) => widget is DropdownButtonFormField,
      );
      expect(selector, findsOneWidget);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text(loc.vaultRecoveryDescriptorEntry).last);
      await tester.pumpAndSettle();
      expect(find.text('descriptor input'), findsOneWidget);
      final abandoned =
          verify(
                () => backups.recoverVaults(
                  words: null,
                  abandoned: captureAny(named: 'abandoned'),
                ),
              ).captured.single
              as bool Function();
      expect(abandoned(), isTrue);
      nativeRestoring!(true);
      await tester.pump();
      expect(
        tester.widget<DropdownButtonFormField>(selector).onChanged,
        isNull,
      );
      nativeRestoring!(false);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text(loc.dataBackupWordsTitle).last);
      await tester.pumpAndSettle();
      expect(find.byType(VaultWordsRecoveryScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      pending.complete(const Err(WalletBackupCredentialFailure()));
      await tester.pumpAndSettle();
      expect(find.text(loc.vaultRecoveryNoCredential), findsNothing);
      verifyNoMoreInteractions(backups);
    },
  );
}
