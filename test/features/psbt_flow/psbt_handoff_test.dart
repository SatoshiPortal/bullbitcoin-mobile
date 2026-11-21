import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/psbt_flow/show_psbt/show_psbt_screen.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final confirm in [true, false]) {
    testWidgets(
      'PSBT ${confirm ? 'Done returns a handoff confirmation' : 'back cancels the handoff'}',
      (tester) async {
        PsbtHandoffResult? result;
        var returned = false;
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await context.push<PsbtHandoffResult>('/sign');
                    returned = true;
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
            GoRoute(
              path: '/sign',
              builder: (_, _) => const ShowPsbtScreen(psbt: 'unsigned'),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: const [
              bullUiLocalizationsDelegate,
              ...appLocalizationsDelegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        if (confirm) {
          final context = tester.element(find.byType(ShowPsbtScreen));
          await tester.tap(
            find.text(AppLocalizations.of(context).psbtFlowDone),
          );
        } else {
          router.pop();
        }
        await tester.pumpAndSettle();
        expect(returned, isTrue);
        expect(
          result,
          confirm ? PsbtHandoffResult.readyToReadSignedTransaction : null,
        );
        expect(find.text('Open'), findsOneWidget);
      },
    );
  }
}
