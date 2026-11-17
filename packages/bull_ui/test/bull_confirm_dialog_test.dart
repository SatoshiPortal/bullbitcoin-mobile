import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart' show Builder;
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullConfirmDialog', () {
    Future<Future<bool>> open(
      WidgetTester tester, {
      bool destructive = false,
    }) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        wrapWithTheme(
          Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final result = BullConfirmDialog.show(
        ctx,
        title: 'Delete server?',
        message: 'The server will be removed.',
        confirmLabel: 'Delete',
        cancelLabel: 'Cancel',
        destructive: destructive,
      );
      await tester.pumpAndSettle();
      return result;
    }

    BullButton button(WidgetTester tester, String label) => tester.widget(
      find.ancestor(of: find.text(label), matching: find.byType(BullButton)),
    );

    testWidgets('completes with true when confirmed', (tester) async {
      final result = await open(tester);
      expect(find.text('Delete server?'), findsOneWidget);
      expect(find.text('The server will be removed.'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(await result, isTrue);
      expect(find.text('Delete server?'), findsNothing);
    });

    testWidgets('completes with false when cancelled', (tester) async {
      final result = await open(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await result, isFalse);
    });

    testWidgets('completes with false when dismissed', (tester) async {
      final result = await open(tester);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(await result, isFalse);
    });

    testWidgets('paints a destructive confirmation with the theme error', (
      tester,
    ) async {
      await open(tester, destructive: true);

      final confirm = button(tester, 'Delete');
      expect(confirm.bgColor, testBullTheme.error);
      expect(confirm.textColor, testBullTheme.onError);
    });

    testWidgets('paints a plain confirmation with the theme primary', (
      tester,
    ) async {
      await open(tester);

      final confirm = button(tester, 'Delete');
      expect(confirm.bgColor, testBullTheme.primary);
      expect(confirm.textColor, testBullTheme.onPrimary);
    });
  });
}
