import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:custom_sliding_segmented_control/custom_sliding_segmented_control.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

void main() {
  final colors = testBullTheme.copyWith(
    border: const Color(0xFF123456),
    secondaryFixedDim: const Color(0xFFABCDEF),
  );
  Widget app(Widget child, {Brightness brightness = Brightness.light}) =>
      MaterialApp(
        theme: ThemeData(
          brightness: brightness,
          extensions: bullUiExtensions(colors: colors, brightness: brightness),
        ),
        localizationsDelegates: bullUiLocalizationsDelegates,
        supportedLocales: BullUiLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );
  for (final compact in [false, true]) {
    testWidgets('amount frame uses semantic border, compact=$compact', (
      tester,
    ) async {
      final controller = TextEditingController(text: '25000');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        app(
          BullAmountInput(
            canonicalUnit: BitcoinUnit.sats,
            amountController: controller,
            compact: compact,
            framed: !compact,
          ),
        ),
      );
      final frames = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(BullAmountInput),
              matching: find.byType(Container),
            ),
          )
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>()
          .where((decoration) => decoration.border != null)
          .toList();
      expect(frames, hasLength(1));
      expect(frames.single.border, Border.all(color: colors.border));
      expect(frames.single.color, colors.surface);
    });
  }
  for (final name in ['tile', 'copy', 'pin']) {
    testWidgets('$name field uses surface and semantic border', (tester) async {
      final widget = switch (name) {
        'tile' => const BullBorderedTile(child: Text('Public value')),
        'copy' => const BullCopyField(
          text: 'Public value',
          copiedMessage: 'Copied',
        ),
        _ => BullPinDots(
          value: '',
          obscure: true,
          onToggleObscure: () {},
          showLabel: 'Show',
          hideLabel: 'Hide',
        ),
      };
      await tester.pumpWidget(app(widget));
      final decorations = [
        ...tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(widget.runtimeType),
                matching: find.byType(Container),
              ),
            )
            .map((widget) => widget.decoration),
        ...tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(widget.runtimeType),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((widget) => widget.decoration),
      ].whereType<BoxDecoration>().where((d) => d.border != null).toList();
      expect(decorations, isNotEmpty);
      for (final decoration in decorations) {
        expect(decoration.color, colors.surface);
        expect(decoration.border, Border.all(color: colors.border));
      }
    });
  }
  for (final brightness in Brightness.values) {
    testWidgets(
      'selected segment uses page background, track unchanged: $brightness',
      (tester) async {
        await tester.pumpWidget(
          app(
            BullSegmented(items: const {'Fast', 'Custom'}, onSelected: (_) {}),
            brightness: brightness,
          ),
        );
        final control = tester.widget<CustomSlidingSegmentedControl<String>>(
          find.byWidgetPredicate(
            (widget) => widget is CustomSlidingSegmentedControl<String>,
          ),
        );
        expect(
          (control.thumbDecoration as BoxDecoration?)?.color,
          colors.background,
        );
        expect(
          (control.decoration as BoxDecoration?)?.color,
          brightness == Brightness.dark
              ? colors.surfaceContainer
              : colors.textMuted.withValues(alpha: 0.1),
        );
      },
    );
    for (final width in [390.0, 900.0]) {
      testWidgets(
        'global sheet is filled, borderless and edge-to-edge: $brightness/$width',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            app(
              Builder(
                builder: (context) => TextButton(
                  onPressed: () => BullBottomSheet.show<void>(
                    context: context,
                    child: const SizedBox(
                      height: 120,
                      child: Text('Public content'),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
              brightness: brightness,
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
          expect(
            sheet.backgroundColor,
            brightness == Brightness.light ? colors.background : colors.surface,
          );
          expect(
            (sheet.shape as RoundedRectangleBorder?)?.side,
            BorderSide.none,
          );
          expect(
            (sheet.shape as RoundedRectangleBorder?)?.borderRadius,
            const BorderRadius.vertical(top: Radius.circular(8)),
          );
          final bounds = tester.getRect(find.byType(BottomSheet));
          expect(bounds.left, 0);
          expect(bounds.right, width);
          final barrier = tester
              .widgetList<ModalBarrier>(find.byType(ModalBarrier))
              .where((widget) => widget.color != null)
              .last;
          expect(
            barrier.color,
            colors.scrim.withValues(
              alpha: brightness == Brightness.light ? 0.45 : 0.60,
            ),
          );
        },
      );
    }
  }
  testWidgets(
    'Bull test theme supplies primary cursor, handles and selection',
    (tester) async {
      await tester.pumpWidget(wrapWithTheme(const TextField()));
      await tester.tap(find.byType(TextField));
      await tester.pump();
      final context = tester.element(find.byType(TextField));
      final selection = TextSelectionTheme.of(context);
      expect(selection.cursorColor, testBullTheme.primary);
      expect(selection.selectionHandleColor, testBullTheme.primary);
      expect(
        selection.selectionColor,
        testBullTheme.primary.withValues(alpha: 0.3),
      );
    },
  );
  testWidgets(
    'owned and caller-owned trailing controls preserve action ownership',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          BullInputText(
            value: '',
            onChanged: (_) {},
            rightIcon: GestureDetector(
              onTap: () => taps++,
              child: const SizedBox(
                width: 64,
                height: 40,
                child: Text('Unit toggle'),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(BullFieldAction), findsNothing);
      await tester.tap(find.text('Unit toggle'));
      expect(taps, 1);
      expect(
        tester.getSize(find.widgetWithText(SizedBox, 'Unit toggle')).width,
        64,
      );
      await tester.pumpWidget(
        wrapWithTheme(
          BullInputText(
            value: '',
            onChanged: (_) {},
            rightIcon: const Text('Public unit'),
          ),
        ),
      );
      expect(find.byType(BullFieldAction), findsNothing);
      await tester.pumpWidget(
        wrapWithTheme(
          BullInputText(
            value: '',
            onChanged: (_) {},
            rightIcon: const Text('Owned action'),
            rightActionLabel: 'Edit label',
            onRightTap: () => taps++,
          ),
        ),
      );
      expect(tester.getSize(find.byType(BullFieldAction)), const Size(48, 48));
      expect(
        tester.getSize(
          find.descendant(
            of: find.byType(BullFieldAction),
            matching: find.byType(Ink),
          ),
        ),
        const Size(48, 40),
      );
      await tester.tap(find.byType(BullFieldAction));
      expect(
        DefaultTextStyle.of(tester.element(find.text('Owned action')))
            .style
            .color,
        testBullTheme.onSecondary,
      );
      expect(taps, 2);
    },
  );
}
