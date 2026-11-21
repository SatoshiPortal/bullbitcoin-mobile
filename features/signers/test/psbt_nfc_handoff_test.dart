import 'package:signers/routes.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signers/signers.dart';

void main() {
  for (final success in [true, false]) {
    testWidgets(
      'NFC ${success ? 'success returns confirmation' : 'cancellation keeps the screen open'}',
      (tester) async {
        PsbtHandoffResult? result;
        String? written;
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await context.push<PsbtHandoffResult>('/sign');
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
            GoRoute(
              path: '/sign',
              builder: (_, _) => ShowPsbtScreen(
                psbt: 'original unsigned PSBT',
                signerDevice: SignerDeviceEntity.coldcardMk4,
                writeNfc: (_, title, data, onSuccess) async {
                  expect(title, isNotEmpty);
                  written = data;
                  if (success) onSuccess();
                },
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            theme: ThemeData(extensions: testBullExtensions),
            localizationsDelegates: const [
              bullUiLocalizationsDelegate,
              SignersLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
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
        expect(written, 'original unsigned PSBT');
        expect(
          result,
          success ? PsbtHandoffResult.readyToReadSignedTransaction : null,
        );
        expect(
          find.byType(ShowPsbtScreen),
          success ? findsNothing : findsOneWidget,
        );
      },
    );
  }
}
