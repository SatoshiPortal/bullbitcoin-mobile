import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/src/ui/privacy_guard.dart';

void main() {
  // The riskiest concurrency code in the UI: a GLOBAL, non-ref-counted
  // no_screenshot singleton wrapped in a static ref-count so capture stays
  // BLOCKED while ANY guard is mounted and is re-enabled only when the LAST
  // unmounts. A spy injected via the test seam records every transition.
  final transitions = <bool>[]; // true = capture blocked (off), false = on

  setUp(() {
    transitions.clear();
    PrivacyGuard.debugSetCapture = ({required bool enabled}) =>
        transitions.add(enabled);
  });

  tearDown(() => PrivacyGuard.debugSetCapture = null);

  testWidgets('two overlapping guards: stays blocked until the LAST unmounts',
      (tester) async {
    // Mount both guards (a flag toggles each in/out independently).
    var showA = true;
    var showB = true;
    late StateSetter setOuter;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setOuter = setState;
            return Column(
              children: [
                if (showA) const PrivacyGuard(child: SizedBox()),
                if (showB) const PrivacyGuard(child: SizedBox()),
              ],
            );
          },
        ),
      ),
    );
    // First guard's initState enabled the block; the second is a no-op (count
    // 0→1 fires, 1→2 does not).
    expect(transitions, [true]);

    // Unmount the first guard — count 2→1, still mounted → MUST stay blocked.
    transitions.clear();
    showA = false;
    setOuter(() {});
    await tester.pumpAndSettle();
    expect(transitions, isEmpty, reason: 'one guard still mounted');

    // Unmount the second/last guard — count 1→0 → capture re-enabled exactly
    // once.
    showB = false;
    setOuter(() {});
    await tester.pumpAndSettle();
    expect(transitions, [false]);
  });

  testWidgets('covers the child whenever the app is not resumed (app-switcher)',
      (tester) async {
    const secretKey = Key('secret');
    await tester.pumpWidget(
      const MaterialApp(
        home: PrivacyGuard(child: Text('shh', key: secretKey)),
      ),
    );
    // Resumed: the child is visible and not covered.
    expect(find.byKey(secretKey), findsOneWidget);
    expect(find.byKey(PrivacyGuard.coverKey), findsNothing);

    // Backgrounded (the OS snapshots here): an opaque cover is painted over the
    // child so the secret is absent from the multitasking thumbnail. The child
    // stays in the tree (state preserved), just hidden under the cover.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byKey(PrivacyGuard.coverKey), findsOneWidget);
    expect(find.byKey(secretKey), findsOneWidget);

    // Resumed again: cover removed.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(PrivacyGuard.coverKey), findsNothing);
  });

  testWidgets('covers the child until capture-blocking is confirmed '
      '(first-frame gap)', (tester) async {
    // With NO test seam the real async screenshotOff() path runs: capture is not
    // confirmed synchronously, so the first frame(s) MUST be covered — a capture
    // already in progress catches only the opaque cover, never the secret. This
    // closes the audit's async-first-frame window.
    PrivacyGuard.debugSetCapture = null;
    const secretKey = Key('secret');
    await tester.pumpWidget(
      const MaterialApp(
        home: PrivacyGuard(child: Text('shh', key: secretKey)),
      ),
    );
    await tester.pump(); // first frame — block not yet confirmed
    expect(find.byKey(PrivacyGuard.coverKey), findsOneWidget);
    // The child stays mounted under the cover (state/identity preserved).
    expect(find.byKey(secretKey), findsOneWidget);
  });
}
