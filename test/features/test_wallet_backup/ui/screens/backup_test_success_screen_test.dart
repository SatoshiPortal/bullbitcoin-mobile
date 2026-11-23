import 'package:backups/testing.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/features/wallet/public/recoverbull_bindings.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _Wallet extends Mock implements WalletBloc {}

void main() {
  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    testWidgets('backup verification success in ${theme.name}', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final wallet = _Wallet();
      when(() => wallet.stream).thenAnswer((_) => const Stream.empty());
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => BackupTestSuccessScreen(
              successImage: AssetImage(Assets.animations.successTick.path),
              onContinue: () {
                WalletRecoverBullBindings.tested(context);
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
        BlocProvider<WalletBloc>.value(
          value: wallet,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.themeData(theme),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final success = find.byType(BackupTestSuccessScreen);
      final loc = AppLocalizations.of(tester.element(success));
      expect(find.text(loc.testBackupSuccessTitle), findsOneWidget);
      verifyNever(() => wallet.add(const VerifyBackupStatus()));
      await tester.tap(find.text(loc.testBackupSuccessButton));
      await tester.pumpAndSettle();
      verify(() => wallet.add(const VerifyBackupStatus())).called(1);
      expect(find.text('Wallet destination'), findsOneWidget);
    });
  }
}
