import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/settings/ui/widgets/not_logged_in_bottom_sheet.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

enum _Sheet { deleteAccount, deleted, logout, signIn }

class _SheetObserver extends NavigatorObserver {
  int pops = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is ModalBottomSheetRoute<dynamic>) pops++;
  }
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Golos Text',
    )..addFont(rootBundle.load('assets/fonts/GolosText.ttf'))).load();
  });

  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    for (final action in _Sheet.values) {
      testWidgets('${action.name} in ${theme.name}', (tester) async {
        final observer = _SheetObserver();
        var confirmations = 0;
        Future<void> confirm() async {
          expect(observer.pops, 2);
          confirmations++;
        }

        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = GoRouter(
          observers: [observer],
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: Center(
                  child: BullButton.secondary(
                    label: 'Open account sheet',
                    onPressed: () => switch (action) {
                      _Sheet.deleteAccount =>
                        ExchangeAccountSheets.confirmDeletion(
                          context,
                          onConfirm: confirm,
                        ),
                      _Sheet.deleted =>
                        ExchangeAccountSheets.showDeletionRequested(context),
                      _Sheet.logout => ExchangeAccountSheets.confirmLogout(
                        context,
                        onConfirm: confirm,
                      ),
                      _Sheet.signIn => NotLoggedInBottomSheet.show(context),
                    },
                  ),
                ),
              ),
            ),
            GoRoute(
              path: ExchangeRoute.exchangeHome.path,
              name: ExchangeRoute.exchangeHome.name,
              builder: (_, _) =>
                  const Scaffold(body: Text('Exchange destination')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.themeData(theme),
            localizationsDelegates: const [
              bullUiLocalizationsDelegate,
              ...appLocalizationsDelegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        final open = find.text('Open account sheet');
        await tester.tap(open);
        await tester.pumpAndSettle();
        final sheet = find.byType(BullBottomSheet);
        expect(sheet, findsOneWidget);
        final loc = AppLocalizations.of(tester.element(sheet));

        final cancelLabel = switch (action) {
          _Sheet.deleteAccount => loc.deleteAccountConfirmationCancel,
          _Sheet.logout => loc.logoutConfirmationCancel,
          _ => null,
        };
        if (cancelLabel != null) {
          await tester.tap(find.text(cancelLabel));
          await tester.pumpAndSettle();
          expect(sheet, findsNothing);
          expect(confirmations, 0);
          await tester.tap(open);
          await tester.pumpAndSettle();
        }
        if (action == _Sheet.deleted) {
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();
          expect(sheet, findsOneWidget);
        }

        final actionLabel = switch (action) {
          _Sheet.deleteAccount => loc.deleteAccountConfirmationDelete,
          _Sheet.deleted => loc.deleteAccountSuccessClose,
          _Sheet.logout => loc.logoutConfirmationLogout,
          _Sheet.signIn => loc.loginButton,
        };
        await tester.tap(find.widgetWithText(BullButton, actionLabel));
        await tester.pumpAndSettle();
        expect(sheet, findsNothing);
        expect(confirmations, cancelLabel == null ? 0 : 1);
        if (action == _Sheet.signIn) {
          expect(find.text('Exchange destination'), findsOneWidget);
        }
      });
    }
  }
}
