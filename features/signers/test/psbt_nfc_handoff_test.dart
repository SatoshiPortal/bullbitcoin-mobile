import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signers/routes.dart';
import 'package:signers/signers.dart';
import 'package:signers/src/psbt_flow/show_psbt/show_psbt_screen.dart';

void main() {
  for (final outcome in [
    'success',
    'cancellation',
    'completion after disposal',
  ]) {
    testWidgets('mounted PSBT NFC handoff handles $outcome', (tester) async {
      const psbt = 'original unsigned PSBT';
      PsbtHandoffResult? result;
      var returned = false;
      String? written;
      VoidCallback? completeWrite;
      final services = GetIt.asNewInstance();
      addTearDown(services.reset);
      final feature = SignersFeature.mount(
        services: services,
        writeNfc: (_, title, data, onSuccess) async {
          expect(title, contains(SignerDevice.coldcardMk4.displayName));
          written = data;
          completeWrite = onSuccess;
          if (outcome == 'success') onSuccess();
        },
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await SignersNavigation.showPsbt(
                    context,
                    psbt: psbt,
                    signerDevice: SignerDevice.coldcardMk4,
                  );
                  returned = true;
                },
                child: const Text('Open'),
              ),
            ),
          ),
          ...feature.routes,
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(extensions: testBullExtensions),
          localizationsDelegates: const [
            bullUiLocalizationsDelegate,
            ...SignersLocalizations.localizationsDelegates,
          ],
          supportedLocales: SignersLocalizations.supportedLocales,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(ShowPsbtScreen));
      await tester.tap(
        find.text(SignersLocalizations.of(context).psbtFlowSignViaNfc),
      );
      await tester.pumpAndSettle();
      expect(written, psbt);
      if (outcome == 'success') {
        expect(result, PsbtHandoffResult.readyToReadSignedTransaction);
        expect(returned, isTrue);
        expect(find.byType(ShowPsbtScreen), findsNothing);
      } else {
        expect(returned, isFalse);
        expect(find.byType(ShowPsbtScreen), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        if (outcome == 'completion after disposal') {
          expect(context.mounted, isFalse);
          expect(completeWrite, isNotNull);
          completeWrite?.call();
          await tester.pumpAndSettle();
        }
        expect(returned, isTrue);
        expect(result, isNull);
        expect(find.text('Open'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
