import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/backup_settings/public/backup_settings_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:bb_mobile/seed_recovery_completion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  final loc = AppLocalizationsEn();
  for (final accept in [false, true]) {
    testWidgets('physical restore checks once only after consent: $accept', (
      tester,
    ) async {
      var opened = 0;
      var complete = false;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  await offerDataBackupAfterPhysicalRestore(context, {
                    'new-wallet': null,
                  });
                  complete = true;
                },
                child: const Text('Finish physical restore fixture'),
              ),
            ),
          ),
          GoRoute(
            name: BackupSettingsRoute.dataRecovery.name,
            path: BackupSettingsRoute.dataRecovery.path,
            builder: (context, state) {
              opened++;
              final args = state.extra! as DataBackupRecoveryArgs;
              expect(args.enableAfterRecovery, isTrue);
              expect(args.initialWalletLabels, {'new-wallet': null});
              return Scaffold(
                body: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Finish backup fixture'),
                ),
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish physical restore fixture'));
      await tester.pumpAndSettle();
      expect(opened, 0);
      expect(complete, isFalse);
      expect(find.text(loc.dataBackupRestoreCheckTitle), findsOneWidget);
      await tester.tap(
        find.text(accept ? loc.dataBackupCheckServer : loc.cancelButton),
      );
      await tester.pumpAndSettle();
      expect(opened, accept ? 1 : 0);
      if (accept) {
        expect(complete, isFalse);
        await tester.tap(find.text('Finish backup fixture'));
        await tester.pumpAndSettle();
      }
      expect(complete, isTrue);
      expect(find.text(loc.dataBackupRestoreCheckTitle), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
