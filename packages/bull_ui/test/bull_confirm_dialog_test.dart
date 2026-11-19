import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart'
    show Builder, Container, BoxDecoration;
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

    testWidgets('announces itself as a route named by its title', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await open(tester);

      final title = find.semantics.byPredicate(
        (node) =>
            node.label == 'Delete server?' && node.flagsCollection.namesRoute,
      );
      expect(title, findsOne);
      expect(
        find.semantics.ancestor(
          of: title,
          matching: find.semantics.byPredicate(
            (node) => node.flagsCollection.scopesRoute,
          ),
        ),
        findsAtLeast(1),
      );
      semantics.dispose();
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

    testWidgets(
      'paints a destructive confirmation with primary and cancel with secondary',
      (tester) async {
        await open(tester, destructive: true);

        final confirm = button(tester, 'Delete');
        final fill =
            tester
                    .widget<Container>(
                      find
                          .descendant(
                            of: find.widgetWithText(BullButton, 'Delete'),
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        expect(fill.color, testBullTheme.primary);
        expect(confirm.outlined, isFalse);
        final cancelFill =
            tester
                    .widget<Container>(
                      find
                          .descendant(
                            of: find.widgetWithText(BullButton, 'Cancel'),
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        expect(cancelFill.color, testBullTheme.secondary);
      },
    );

    testWidgets('paints a plain confirmation with the theme primary', (
      tester,
    ) async {
      await open(tester);

      final confirm = button(tester, 'Delete');
      final fill =
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.widgetWithText(BullButton, 'Delete'),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(fill.color, testBullTheme.primary);
      expect(confirm.disabled, isFalse);
    });
  });
}
