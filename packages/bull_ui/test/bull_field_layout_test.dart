import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const choices = [
  BullPickerItem(value: 'a', label: 'Apple'),
  BullPickerItem(value: 'b', label: 'Banana'),
];

void main() {
  for (final picked in ['a', 'b']) {
    testWidgets('cover anchor overlaps its field and picks $picked once', (
      tester,
    ) async {
      final calls = <String>[];
      await tester.pumpWidget(
        wrapWithTheme(
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 100, 24, 0),
            child: BullDropdown<String>(
              value: 'a',
              items: choices,
              coverAnchor: true,
              onChanged: calls.add,
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
      final first = tester.getRect(
        find.widgetWithText(PopupMenuItem<int>, 'Apple'),
      );
      expect(menu.top, closeTo(field.top, 1));
      expect(menu.width, closeTo(field.width, 1));
      expect(first.top, lessThan(field.bottom));
      await tester.tap(find.text(picked == 'a' ? 'Apple' : 'Banana').last);
      await tester.pumpAndSettle();
      expect(calls, [picked]);
      expect(find.byType(PopupMenuItem<int>), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('covered menu dismissal and disabled field do not pick', (
    tester,
  ) async {
    final calls = <String>[];
    Widget field(ValueChanged<String>? onChanged) => wrapWithTheme(
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 100, 24, 0),
        child: BullDropdown<String>(
          value: 'a',
          items: choices,
          coverAnchor: true,
          onChanged: onChanged,
        ),
      ),
    );
    await tester.pumpWidget(field(calls.add));
    await tester.tap(find.byType(BullDropdown<String>));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    await tester.pumpWidget(field(null));
    await tester.tap(find.byType(BullDropdown<String>));
    await tester.pumpAndSettle();
    expect(find.text('Banana'), findsNothing);
    expect(calls, isEmpty);
  });
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('heading padding keeps Copy 48dp $brightness scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final writes = <Object?>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') writes.add(call.arguments);
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        Widget app(EdgeInsetsGeometry? padding) => MaterialApp(
          theme: ThemeData(
            brightness: brightness,
            extensions: bullUiExtensions(
              colors: testBullTheme,
              brightness: brightness,
            ),
            textTheme: testBullTypography.toTextTheme(),
          ),
          localizationsDelegates: bullUiLocalizationsDelegates,
          supportedLocales: BullUiLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child ?? const SizedBox(),
          ),
          home: Scaffold(
            body: padding == null
                ? const BullCopyField(
                    label: 'Receive address',
                    text: 'public-full-address',
                    copiedMessage: 'Copied',
                  )
                : BullCopyField(
                    label: 'Receive address',
                    text: 'public-full-address',
                    copiedMessage: 'Copied',
                    labelPadding: padding,
                  ),
          ),
        );
        await tester.pumpWidget(app(null));
        await tester.pumpAndSettle();
        final original = tester.getRect(find.byType(BullCopyField));
        final heading = tester.getTopLeft(find.text('Receive address'));
        final copyBefore = tester.getRect(find.byType(IconButton));
        expect(copyBefore.width, greaterThanOrEqualTo(48));
        expect(copyBefore.height, greaterThanOrEqualTo(48));
        await tester.pumpWidget(
          app(
            const EdgeInsets.fromLTRB(
              BullSpacing.md,
              BullSpacing.xxs,
              BullSpacing.md,
              0,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.text('Receive address')).dy,
          closeTo(heading.dy - 8, .01),
        );
        expect(
          tester.getSize(find.byType(BullCopyField)).height,
          closeTo(original.height - 8, .01),
        );
        final copy = tester.getRect(find.byType(IconButton));
        expect(copy.size, copyBefore.size);
        expect(
          tester.widget<IconButton>(find.byType(IconButton)).tooltip,
          'Copy',
        );
        await tester.tapAt(copy.centerLeft + const Offset(1, 0));
        await tester.pump();
        expect(writes, [
          {'text': 'public-full-address'},
        ]);
        expect(find.text('Copied'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
