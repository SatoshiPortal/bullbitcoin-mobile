import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';

import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact action works in AlertDialog intrinsic layout', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      wrapWithTheme(
        AlertDialog(
          title: const Text('Try again'),
          actions: [
            BullButton.secondary(
              label: 'Retry',
              compact: true,
              size: BullButtonSize.small,
              onPressed: () => taps++,
            ),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Retry'));
    expect(taps, 1);
  });
  testWidgets(
    'legacy constructors preserve explicit appearance and disable taps',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          Column(
            children: [
              BullButton.big(
                label: 'Big',
                bgColor: testBullTheme.error,
                textColor: testBullTheme.onError,
                onPressed: () => taps++,
              ),
              BullButton.small(
                label: 'Small',
                bgColor: testBullTheme.surface,
                textColor: testBullTheme.text,
                borderColor: testBullTheme.border,
                outlined: true,
                compact: true,
                disabled: true,
                onPressed: () => taps++,
              ),
            ],
          ),
        ),
      );
      final bigScope = find.widgetWithText(BullButton, 'Big');
      final smallScope = find.widgetWithText(BullButton, 'Small');
      BoxDecoration decoration(Finder scope) =>
          tester
                  .widget<Container>(
                    find
                        .descendant(of: scope, matching: find.byType(Container))
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration(bigScope).color, testBullTheme.error);
      expect(
        tester
            .widget<BullText>(
              find.descendant(of: bigScope, matching: find.byType(BullText)),
            )
            .color,
        testBullTheme.onError,
      );
      expect(decoration(smallScope).color, testBullTheme.surface);
      expect(
        decoration(smallScope).border,
        Border.all(color: testBullTheme.border),
      );
      expect(
        tester
            .getSize(
              find.descendant(of: smallScope, matching: find.byType(InkWell)),
            )
            .height,
        36,
      );
      expect(
        tester
            .widget<InkWell>(
              find.descendant(of: smallScope, matching: find.byType(InkWell)),
            )
            .onTap,
        isNull,
      );
      await tester.tap(find.text('Small'), warnIfMissed: false);
      expect(taps, 0);
      await tester.tap(find.text('Big'));
      expect(taps, 1);
    },
  );

  for (final dark in [false, true]) {
    final colors = dark
        ? testBullTheme.copyWith(
            secondary: testBullTheme.onSecondary,
            onSecondary: testBullTheme.secondary,
          )
        : testBullTheme;
    Widget wrap(Widget child) => MaterialApp(
      theme: ThemeData(
        brightness: dark ? Brightness.dark : Brightness.light,
        extensions: bullUiExtensions(
          colors: colors,
          brightness: dark ? Brightness.dark : Brightness.light,
          typography: testBullTypography,
        ),
      ),
      home: Scaffold(body: Center(child: child)),
    );

    testWidgets('role colors follow the theme (dark: $dark)', (tester) async {
      await tester.pumpWidget(
        wrap(
          Column(
            children: [
              BullButton.primary(
                label: 'Confirm',
                iconData: Icons.check,
                onPressed: () {},
              ),
              BullButton.secondary(
                label: 'Cancel',
                iconData: Icons.close,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      Color? fill(String label) =>
          (tester
                      .widget<Container>(
                        find
                            .descendant(
                              of: find.widgetWithText(BullButton, label),
                              matching: find.byType(Container),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration)
              .color;
      expect(fill('Confirm'), colors.primary);
      expect(fill('Cancel'), colors.secondary);
      for (final (label, foreground) in [
        ('Confirm', colors.onPrimary),
        ('Cancel', colors.onSecondary),
      ]) {
        final scope = find.widgetWithText(BullButton, label);
        expect(
          tester
              .widget<BullText>(
                find.descendant(of: scope, matching: find.byType(BullText)),
              )
              .color,
          foreground,
        );
        expect(
          tester
              .widget<Icon>(
                find.descendant(of: scope, matching: find.byType(Icon)),
              )
              .color,
          foreground,
        );
      }
    });

    testWidgets('disabled role exposes no activation (dark: $dark)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(const BullButton.primary(label: 'Confirm', onPressed: null)),
      );
      final nodes = find.semantics.byPredicate(
        (node) => node.label == 'Confirm' && node.flagsCollection.isButton,
      );
      expect(nodes, findsOne);
      final node = nodes.evaluate().single;
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets(
      'enabled role exposes one action and activates with keyboard (dark: $dark)',
      (tester) async {
        final handle = tester.ensureSemantics();
        var taps = 0;
        await tester.pumpWidget(
          wrap(BullButton.primary(label: 'Confirm', onPressed: () => taps++)),
        );
        final nodes = find.semantics.byPredicate(
          (node) => node.label == 'Confirm' && node.flagsCollection.isButton,
        );
        expect(nodes, findsOne);
        expect(
          nodes.evaluate().single.getSemanticsData().hasAction(
            SemanticsAction.tap,
          ),
          isTrue,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(taps, 1);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        handle.dispose();
      },
    );

    testWidgets('default compact keeps a 48 dp target (dark: $dark)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          BullButton.secondary(label: 'OK', compact: true, onPressed: () {}),
        ),
      );
      final size = tester.getSize(find.byType(InkWell));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('compact target stays at least 48 dp (dark: $dark)', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          BullButton.secondary(
            label: 'OK',
            compact: true,
            height: 24,
            width: 24,
            onPressed: () => taps++,
          ),
        ),
      );
      final size = tester.getSize(find.byType(InkWell));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(find.text('OK'));
      expect(taps, 1);
    });

    testWidgets(
      'advanced link has themed underline and a 48 dp target (dark: $dark)',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          wrap(
            BullAdvancedOptionsLink(
              label: 'Advanced options',
              onPressed: () => taps++,
            ),
          ),
        );
        final button = tester.widget<TextButton>(find.byType(TextButton));
        expect(button.style?.foregroundColor?.resolve({}), colors.primary);
        expect(
          button.style?.textStyle?.resolve({})?.decoration,
          TextDecoration.underline,
        );
        expect(
          tester.getSize(find.byType(TextButton)).height,
          greaterThanOrEqualTo(48),
        );
        expect(
          tester.getSize(find.byType(TextButton)).width,
          greaterThanOrEqualTo(48),
        );
        final text = tester.element(find.text('Advanced options'));
        expect(DefaultTextStyle.of(text).style.color, colors.primary);
        expect(
          DefaultTextStyle.of(text).style.decoration,
          TextDecoration.underline,
        );
        await tester.tap(find.text('Advanced options'));
        expect(taps, 1);
      },
    );
  }
}
