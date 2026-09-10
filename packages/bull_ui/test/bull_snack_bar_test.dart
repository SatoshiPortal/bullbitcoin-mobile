import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  testWidgets('BullSnackBar fires the undo action callback', (tester) async {
    var undone = 0;
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

    BullSnackBar.show(
      ctx,
      message: '2 coins unfrozen',
      leadingIcon: BullIcons.acUnit,
      actionLabel: 'Undo',
      onAction: () => undone++,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('2 coins unfrozen'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(undone, 1);
  });

  testWidgets('BullSnackBar uses the canonical top toast surface', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (value) {
            context = value;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    BullSnackBar.show(context, message: 'Potential attack');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Potential attack'), findsOneWidget);
    final material = tester.widget<Material>(find.byType(Material).last);
    expect(material.color, Colors.transparent);
    final container = tester.widget<Container>(find.byType(Container).last);
    expect((container.decoration! as BoxDecoration).color, isNotNull);
    expect(find.byType(SnackBar), findsNothing);
    expect(
      (container.decoration! as BoxDecoration).borderRadius,
      BorderRadius.circular(20),
    );
    expect(tester.getTopLeft(find.text('Potential attack')).dy, lessThan(300));
    BullSnackBar.dismiss();
    await tester.pumpAndSettle();
  });

  testWidgets('showContent exposes the same concrete canonical widget', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (value) {
            context = value;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    BullSnackBar.showContent(context, const Text('content'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('content'), findsOneWidget);
    expect(
      tester.widget<Container>(find.byType(Container).last).padding,
      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );
    BullSnackBar.dismiss();
    await tester.pumpAndSettle();
  });

  testWidgets('showContent fills the constrained width with 16px margins', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late BuildContext context;
    await tester.pumpWidget(
      wrapWithTheme(
        SizedBox(
          width: 360,
          child: Builder(
            builder: (value) {
              context = value;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    BullSnackBar.showContent(context, const Text('wide'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.getSize(find.byType(Container).last).width, 328);
    BullSnackBar.dismiss();
    await tester.pumpAndSettle();
  });

  testWidgets('a horizontal drag dismisses after crossing 60px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late BuildContext context;
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (value) {
            context = value;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    BullSnackBar.showContent(context, const Text('drag me'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.drag(find.text('drag me'), const Offset(100, 0));
    await tester.pumpAndSettle();

    expect(find.text('drag me'), findsNothing);
  });
}
