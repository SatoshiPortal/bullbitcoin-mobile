import 'dart:async';

import 'package:bull_ark/testing.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    show Builder, MaterialApp, ThemeData;

void main() {
  for (final cancel in [false, true]) {
    testWidgets('scanner pops only its own route; cancellation=$cancel', (
      tester,
    ) async {
      ValueChanged<String>? decode;
      final result = Completer<String?>();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: testBullExtensions),
          home: Builder(
            builder: (context) => BullScaffold(
              body: BullButton.big(
                label: 'Open fixture scanner',
                bgColor: context.bull.primary,
                textColor: context.bull.onPrimary,
                onPressed: () async {
                  result.complete(
                    await scanArkPayment(
                      context,
                      'Fixture scanner',
                      scannerBuilder: (callback) {
                        decode = callback;
                        return const SizedBox.shrink();
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open fixture scanner'));
      await tester.pumpAndSettle();
      final callback = decode;
      if (callback == null) throw StateError('Missing fixture decoder');
      if (cancel) {
        await tester.binding.handlePopRoute();
        // Decoder can finish during the route's exit animation.
        callback('late');
      } else {
        callback('raw-public-fixture');
        callback('duplicate');
      }
      await tester.pumpAndSettle();
      expect(await result.future, cancel ? null : 'raw-public-fixture');
      expect(find.text('Open fixture scanner'), findsOneWidget);
      expect(find.text('Fixture scanner'), findsNothing);
      callback('after-dispose');
      await tester.pumpAndSettle();
      expect(find.text('Open fixture scanner'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
