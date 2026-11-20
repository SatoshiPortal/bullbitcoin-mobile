import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'settings tile fills the field width with a single accessible action',
    (tester) async {
      var taps = 0;
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          wrapWithTheme(
            SizedBox(
              width: 358,
              child: BullSettingsEntryTile(
                label: 'Settings',
                summary: 'Fast',
                onPressed: () => taps++,
              ),
            ),
          ),
        );
        expect(
          tester.getSize(find.byType(BullSettingsEntryTile)),
          const Size(358, 56),
        );
        expect(find.bySemanticsLabel('Settings'), findsOneWidget);
        expect(
          tester.getSemantics(find.byType(BullSettingsEntryTile)),
          matchesSemantics(
            label: 'Settings',
            value: 'Fast',
            isButton: true,
            isFocusable: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        final box = tester.getRect(find.byType(BullSettingsEntryTile));
        await tester.tapAt(Offset(box.right - 1, box.center.dy));
        expect(taps, 1);
        expect(tester, meetsGuideline(androidTapTargetGuideline));
        expect(tester, meetsGuideline(labeledTapTargetGuideline));
        final context = tester.element(find.byType(BullSettingsEntryTile));
        expect(
          tester.widget<Text>(find.text('Fast')).style?.color,
          context.bull.textMuted,
        );
        expect(
          tester.widget<Text>(find.text('Settings')).style?.fontSize,
          context.bullType.body.fontSize,
        );
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('settings tile has both hairlines and decorative icons', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        BullSettingsEntryTile(label: 'Advanced settings', onPressed: () {}),
      ),
    );
    final context = tester.element(find.byType(BullSettingsEntryTile));
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(BullSettingsEntryTile),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration as BoxDecoration;
    final border = decoration.border as Border;
    expect(border.top.width, 1);
    expect(border.bottom.width, 1);
    expect(border.top.color, context.bull.border);
    expect(border.bottom.color, context.bull.border);
    expect(find.byIcon(BullIcons.tune), findsOneWidget);
    expect(find.byIcon(BullIcons.chevronRight), findsOneWidget);
    expect(BullIcons.edit, Icons.edit);
    expect(BullIcons.expandMore, Icons.expand_more);
  });

  testWidgets('settings tile supports long copy at increased text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: SizedBox(
            width: 320,
            child: BullSettingsEntryTile(
              label: 'Advanced settings and transaction options',
              summary: 'Custom network fee',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final summary = tester.widget<Text>(find.text('Custom network fee'));
    expect(summary.maxLines, 1);
    expect(summary.overflow, TextOverflow.ellipsis);
    expect(
      tester.getSize(find.byType(BullSettingsEntryTile)).height,
      greaterThan(56),
    );
  });

  testWidgets('disabled settings tile stays named without a summary', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        wrapWithTheme(
          const BullSettingsEntryTile(
            label: 'Advanced settings',
            onPressed: null,
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(BullSettingsEntryTile)),
        matchesSemantics(
          label: 'Advanced settings',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });
}
