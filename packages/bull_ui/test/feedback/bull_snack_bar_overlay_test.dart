import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('captured root overlay shows an actionable toast after pop', (
    tester,
  ) async {
    late OverlayState overlay;
    var actions = 0;
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (routeContext) {
                  overlay = Overlay.of(routeContext, rootOverlay: true);
                  return Scaffold(
                    body: TextButton(
                      onPressed: () => Navigator.of(routeContext).pop(),
                      child: const Text('Close route'),
                    ),
                  );
                },
              ),
            ),
            child: const Text('Open route'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open route'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close route'));
    await tester.pumpAndSettle();

    BullSnackBar.showOnOverlay(
      overlay,
      message: 'Saved',
      actionLabel: 'Undo',
      onAction: () => actions++,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(actions, 1);
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('an unmounted overlay ignores a toast without a timer', (
    tester,
  ) async {
    late OverlayState overlay;
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) {
            overlay = Overlay.of(context, rootOverlay: true);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(overlay.mounted, isFalse);
    BullSnackBar.showOnOverlay(overlay, message: 'Ignored');
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Ignored'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
