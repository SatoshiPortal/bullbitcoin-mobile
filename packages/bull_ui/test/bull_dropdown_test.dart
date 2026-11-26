import 'package:flutter/services.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

const _fruit = [
  BullPickerItem(value: 'a', label: 'Apple'),
  BullPickerItem(value: 'b', label: 'Banana'),
];

Widget _dark(Widget child) => MaterialApp(
  theme: ThemeData(
    brightness: Brightness.dark,
    extensions: bullUiExtensions(
      colors: testBullTheme.copyWith(
        surface: const Color(0xFF1C1C1E),
        text: const Color(0xFFFFFFFF),
      ),
      brightness: Brightness.dark,
    ),
  ),
  localizationsDelegates: bullUiLocalizationsDelegates,
  supportedLocales: BullUiLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('dropdown and its chevron have one keyboard focus stop', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        Column(
          children: [
            TextButton(onPressed: () {}, child: const Text('Before')),
            BullDropdown<String>(
              items: const [BullPickerItem(value: 'BTC', label: 'Bitcoin')],
              value: 'BTC',
              onChanged: (_) {},
            ),
            TextButton(onPressed: () {}, child: const Text('After')),
          ],
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(Focus.of(tester.element(find.text('After'))).hasFocus, isTrue);
  });

  group('BullDropdown', () {
    testWidgets('reports the tapped item to onChanged', (tester) async {
      String? selected = 'a';
      await tester.pumpWidget(
        wrapWithTheme(
          StatefulBuilder(
            builder: (context, setState) {
              return BullDropdown<String>(
                value: selected,
                onChanged: (v) => setState(() => selected = v),
                items: _fruit,
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Apple'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Banana').last);
      await tester.pumpAndSettle();

      expect(selected, 'b');
      expect(find.text('Banana'), findsOneWidget);
    });

    for (final selected in ['a', 'b']) {
      testWidgets(
        'opens the menu right under the field, as wide as it, with $selected '
        'selected',
        (tester) async {
          await tester.pumpWidget(
            wrapWithTheme(
              Padding(
                padding: const EdgeInsets.all(24),
                child: BullDropdown<String>(
                  value: selected,
                  onChanged: (_) {},
                  items: _fruit,
                ),
              ),
            ),
          );
          final field = tester.getRect(find.byType(BullDropdown<String>));
          await tester.tap(find.byType(BullDropdown<String>));
          await tester.pumpAndSettle();

          final menu = tester.getRect(
            find.ancestor(
              of: find.text('Apple').last,
              matching: find.byType(SingleChildScrollView),
            ),
          );
          expect(menu.top, closeTo(field.bottom, 1));
          expect(menu.left, closeTo(field.left, 1));
          expect(menu.width, closeTo(field.width, 1));
        },
      );
    }

    testWidgets('marks the selected row in primary and bold', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          BullDropdown<String>(value: 'a', onChanged: (_) {}, items: _fruit),
        ),
      );
      await tester.tap(find.text('Apple'));
      await tester.pumpAndSettle();

      final apple = tester.widget<Text>(find.text('Apple').last);
      final banana = tester.widget<Text>(find.text('Banana'));
      expect(apple.style?.color, testBullTheme.primary);
      expect(apple.style?.fontWeight, FontWeight.w500);
      expect(banana.style?.color, testBullTheme.text);
      expect(banana.style?.fontWeight, FontWeight.w400);
    });

    testWidgets('a null-valued item is a real pick, dismissal is not', (
      tester,
    ) async {
      final picks = <String?>[];
      await tester.pumpWidget(
        wrapWithTheme(
          BullDropdown<String?>(
            value: 'a',
            onChanged: picks.add,
            items: const [
              BullPickerItem<String?>(value: null, label: 'Any'),
              BullPickerItem<String?>(value: 'a', label: 'Apple'),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Apple'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(picks, isEmpty);

      await tester.tap(find.text('Apple'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Any'));
      await tester.pumpAndSettle();
      expect(picks, [null]);
    });

    testWidgets('a null onChanged disables the field', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BullDropdown<String>(
            value: 'a',
            onChanged: null,
            items: _fruit,
          ),
        ),
      );
      await tester.tap(find.text('Apple'));
      await tester.pumpAndSettle();
      expect(find.text('Banana'), findsNothing);
    });

    testWidgets('shows the hint until a value matches', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          BullDropdown<String>(
            value: null,
            hint: 'Pick a fruit',
            onChanged: (_) {},
            items: _fruit,
          ),
        ),
      );
      expect(find.text('Pick a fruit'), findsOneWidget);
    });

    testWidgets('validates through an enclosing Form', (tester) async {
      final form = GlobalKey<FormState>();
      await tester.pumpWidget(
        wrapWithTheme(
          Form(
            key: form,
            child: BullDropdown<String>(
              value: null,
              hint: 'Pick a fruit',
              onChanged: (_) {},
              items: _fruit,
              validator: (value) => value == null ? 'Required' : null,
            ),
          ),
        ),
      );
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('reads its colours from the dark palette too', (tester) async {
      await tester.pumpWidget(
        _dark(
          BullDropdown<String>(value: 'a', onChanged: (_) {}, items: _fruit),
        ),
      );
      await tester.tap(find.text('Apple'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final banana = tester.widget<Text>(find.text('Banana'));
      expect(banana.style?.color, const Color(0xFFFFFFFF));
    });
  });

  testWidgets('a trailing detail sits between the label and the chevron', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        BullDropdown<String>(
          items: const [BullPickerItem(value: 'w', label: 'Secure Bitcoin')],
          value: 'w',
          onChanged: (_) {},
          trailing: const Text('10,429 sats'),
        ),
      ),
    );
    final label = tester.getRect(find.text('Secure Bitcoin'));
    final detail = tester.getRect(find.text('10,429 sats'));
    final chevron = tester.getRect(find.byType(BullFieldAction));
    expect(detail.left, greaterThan(label.left));
    expect(detail.right, lessThan(chevron.left));
  });
}
