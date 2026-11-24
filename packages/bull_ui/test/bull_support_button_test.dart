import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

typedef _Call = ({BuildContext context, String? message});

void main() {
  late List<_Call> calls;

  void record(BuildContext context, {String? message}) {
    calls.add((context: context, message: message));
  }

  setUp(() => calls = []);

  Widget scoped(Widget child) {
    return wrapWithTheme(
      BullSupportScope(onContactSupport: record, child: child),
    );
  }

  final variants = <String, Widget Function({String? message})>{
    'big': ({message}) =>
        BullSupportButton.big(label: 'Contact support', message: message),
    'icon': ({message}) =>
        BullSupportButton.icon(label: 'Contact support', message: message),
    'text': ({message}) =>
        BullSupportButton.text(label: 'Contact support', message: message),
    'tile': ({message}) =>
        BullSupportButton.tile(label: 'Contact support', message: message),
  };

  group('BullSupportButton', () {
    testWidgets('.icon shows the unread count and hides it at zero', (
      tester,
    ) async {
      await tester.pumpWidget(
        scoped(const BullSupportButton.icon(label: 'Support', unreadCount: 3)),
      );
      expect(find.text('3'), findsOneWidget);

      await tester.pumpWidget(
        scoped(
          const BullSupportButton.icon(label: 'Support', unreadCount: 120),
        ),
      );
      expect(find.text('99+'), findsOneWidget);

      await tester.pumpWidget(
        scoped(const BullSupportButton.icon(label: 'Support')),
      );
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    });

    for (final MapEntry(key: name, value: build) in variants.entries) {
      testWidgets('.$name forwards its message to the scope', (tester) async {
        await tester.pumpWidget(scoped(build(message: 'Order 42')));

        await tester.tap(find.byType(BullSupportButton));

        expect(calls, hasLength(1));
        expect(calls.single.message, 'Order 42');
      });

      testWidgets('.$name forwards null when it has no message', (
        tester,
      ) async {
        await tester.pumpWidget(scoped(build()));

        await tester.tap(find.byType(BullSupportButton));

        expect(calls, hasLength(1));
        expect(calls.single.message, isNull);
      });

      testWidgets('.$name renders disabled without a scope', (tester) async {
        await tester.pumpWidget(wrapWithTheme(build(message: 'Order 42')));

        await tester.tap(find.byType(BullSupportButton), warnIfMissed: false);

        expect(tester.takeException(), isNull);
        expect(
          find.descendant(
            of: find.byType(BullSupportButton),
            matching: find.byWidgetPredicate(
              (w) =>
                  (w is Opacity && w.opacity < 1) ||
                  (w is AnimatedOpacity && w.opacity < 1),
            ),
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('passes the button context to the action', (tester) async {
      await tester.pumpWidget(
        scoped(const BullSupportButton.text(label: 'Contact support')),
      );

      await tester.tap(find.byType(BullSupportButton));

      expect(calls.single.context.widget, isA<BullSupportButton>());
    });

    testWidgets('the nearest scope wins', (tester) async {
      final outer = <String?>[];
      await tester.pumpWidget(
        wrapWithTheme(
          BullSupportScope(
            onContactSupport: (context, {message}) => outer.add(message),
            child: BullSupportScope(
              onContactSupport: record,
              child: const BullSupportButton.big(
                label: 'Contact support',
                message: 'inner',
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(BullSupportButton));

      expect(calls.single.message, 'inner');
      expect(outer, isEmpty);
    });

    testWidgets('.icon exposes its label as the tooltip', (tester) async {
      await tester.pumpWidget(
        scoped(const BullSupportButton.icon(label: 'Support Chat')),
      );

      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.tooltip, 'Support Chat');
      expect(find.byType(Tooltip), findsOneWidget);
    });

    testWidgets('.big preserves explicit primary colours', (tester) async {
      await tester.pumpWidget(
        scoped(
          BullSupportButton.big(
            label: 'Contact support',
            bgColor: testBullTheme.primary,
            textColor: testBullTheme.onPrimary,
          ),
        ),
      );
      final scope = find.byType(BullButton);
      final fill =
          tester
                  .widget<Container>(
                    find
                        .descendant(of: scope, matching: find.byType(Container))
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      final text = tester.widget<BullText>(
        find.descendant(of: scope, matching: find.byType(BullText)),
      );
      expect(fill.color, testBullTheme.primary);
      expect(text.color, testBullTheme.onPrimary);
      await tester.tap(find.text('Contact support'));
      expect(calls, hasLength(1));
    });

    testWidgets('.big defaults to the secondary colours', (tester) async {
      await tester.pumpWidget(
        scoped(const BullSupportButton.big(label: 'Contact support')),
      );

      final scope = find.byType(BullButton);
      final fill =
          tester
                  .widget<Container>(
                    find
                        .descendant(of: scope, matching: find.byType(Container))
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      final text = tester.widget<BullText>(
        find.descendant(of: scope, matching: find.byType(BullText)),
      );
      expect(fill.color, testBullTheme.secondary);
      expect(text.color, testBullTheme.onSecondary);
    });
  });
}
