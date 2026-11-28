import 'dart:async';

import 'package:backups/testing.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:overview/routes.dart';

import '../../../overview/support/overview_home_harness.dart';

import 'package:bb_mobile/localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    testWidgets('backup verification success in ${theme.name}', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final home = OverviewHomeHarness();
      await tester.runAsync(home.mount);
      final readsBefore = home.backupReadsStarted;
      addTearDown(home.close);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => BackupTestSuccessScreen(
              successImage: AssetImage(Assets.animations.successTick.path),
              onContinue: () {
                unawaited(home.controller.verifyBackup());
                context.goNamed(WalletRoute.walletHome.name);
              },
            ),
          ),
          GoRoute(
            name: WalletRoute.walletHome.name,
            path: '/wallet-home',
            builder: (_, _) => const Scaffold(body: Text('Wallet destination')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.themeData(theme),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();
      final success = find.byType(BackupTestSuccessScreen);
      final loc = AppLocalizations.of(tester.element(success));
      expect(find.text(loc.testBackupSuccessTitle), findsOneWidget);
      expect(home.backupReadsStarted, readsBefore);
      await tester.tap(find.text(loc.testBackupSuccessButton));
      await tester.pumpAndSettle();
      expect(home.backupReadsStarted, readsBefore + 1);
      expect(find.text('Wallet destination'), findsOneWidget);
    });
  }
}
