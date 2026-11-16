import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  group('BullSettingsEntryItem', () {
    testWidgets('draws the leading widget instead of the icon', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BullSettingsEntryItem(
            icon: Icons.code,
            title: 'Source code',
            leading: SizedBox(key: ValueKey('glyph')),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('glyph')), findsOneWidget);
      expect(find.byIcon(Icons.code), findsNothing);
    });

    testWidgets('keeps the icon without a leading widget', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const BullSettingsEntryItem(icon: Icons.code, title: 'Source code'),
        ),
      );

      expect(find.byIcon(Icons.code), findsOneWidget);
    });
  });
  testWidgets('long titles wrap without hiding the action', (tester) async {
    const label = 'Recover with Data Recovery Words';
    var taps = 0;
    await tester.pumpWidget(
      wrapWithTheme(
        Center(
          child: SizedBox(
            width: 280,
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: BullSettingsEntryItem(
                icon: Icons.restore,
                title: label,
                titleMaxLines: null,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      ),
    );
    final text = find.text(label);
    expect(
      tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
      isFalse,
    );
    expect(
      tester.getSize(find.byType(BullSettingsEntryItem)).height,
      greaterThan(56),
    );
    await tester.tap(text);
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}
