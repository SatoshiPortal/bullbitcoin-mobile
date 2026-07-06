import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/src/ui/privacy_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The riskiest concurrency code in the UI: a GLOBAL, non-ref-counted
  // no_screenshot singleton wrapped in a static ref-count so capture stays
  // BLOCKED while ANY guard is mounted and is re-enabled only when the LAST
  // unmounts. A spy injected via the test seam records every transition.
  final transitions = <bool>[]; // true = capture blocked (off), false = on

  setUp(() {
    transitions.clear();
    PrivacyGuard.debugReset(); // statics leak across tests — start clean.
    PrivacyGuard.debugSetCapture = ({required bool enabled}) =>
        transitions.add(enabled);
  });

  tearDown(() {
    PrivacyGuard.debugSetCapture = null;
    PrivacyGuard.debugReset();
  });

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

  const noScreenshotChannel =
      MethodChannel('com.flutterplaza.no_screenshot_methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  testWidgets(
      'M1: a second guard mounted in the same frame uncovers once the block is '
      'confirmed (not stuck covered forever)', (tester) async {
    // No synchronous seam → the real async screenshotOff() path runs. Gate the
    // no_screenshot channel with a Completer so confirmation timing is
    // deterministic. Before the M1 fix only the guard that armed the block
    // learned of the confirmation; a sibling mounted the SAME frame read the
    // then-false state in initState, never got a rebuild, and stayed covered
    // forever. Now the confirmation is an observable shared notifier.
    PrivacyGuard.debugSetCapture = null;
    final gate = Completer<void>();
    messenger.setMockMethodCallHandler(noScreenshotChannel, (_) async {
      await gate.future; // hold confirmation pending until released
      return true;
    });
    addTearDown(
        () => messenger.setMockMethodCallHandler(noScreenshotChannel, null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            PrivacyGuard(child: SizedBox(key: Key('a'))),
            PrivacyGuard(child: SizedBox(key: Key('b'))),
          ],
        ),
      ),
    );
    await tester.pump();
    // Both guards covered while confirmation is pending (one cover each).
    expect(find.byKey(PrivacyGuard.coverKey), findsNWidgets(2));
    expect(PrivacyGuard.debugCaptureConfirmed, isFalse);

    gate.complete(); // block confirmed
    await tester.pumpAndSettle();
    // BOTH guards uncover — the shared confirmation reaches the sibling too.
    expect(find.byKey(PrivacyGuard.coverKey), findsNothing);
    expect(PrivacyGuard.debugCaptureConfirmed, isTrue);
  });

  testWidgets(
      'M2: a disable during an in-flight enable is not clobbered by the stale '
      'enable completion', (tester) async {
    // Enable is gated (in flight). A disable then runs (guard unmounts), setting
    // confirmed=false and bumping the generation. When the STALE enable finally
    // resolves it must NOT resurrect confirmed=true (which would let the next
    // guard skip its first-frame cover while capture is actually allowed).
    PrivacyGuard.debugSetCapture = null;
    final enableGate = Completer<void>();
    var callIndex = 0;
    messenger.setMockMethodCallHandler(noScreenshotChannel, (_) async {
      if (callIndex++ == 0) await enableGate.future; // gate only the enable
      return true;
    });
    addTearDown(
        () => messenger.setMockMethodCallHandler(noScreenshotChannel, null));

    var show = true;
    late StateSetter setOuter;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setOuter = setState;
            return show ? const PrivacyGuard(child: SizedBox()) : const SizedBox();
          },
        ),
      ),
    );
    await tester.pump();
    expect(PrivacyGuard.debugCaptureConfirmed, isFalse); // enable pending

    // Unmount the guard → disable runs synchronously: confirmed=false, gen++.
    show = false;
    setOuter(() {});
    await tester.pump();
    expect(PrivacyGuard.debugCaptureConfirmed, isFalse);

    // The stale enable now resolves — the generation guard must drop it.
    enableGate.complete();
    await tester.pumpAndSettle();
    expect(PrivacyGuard.debugCaptureConfirmed, isFalse,
        reason: 'stale enable completion must not reopen the M2 window');
  });
}
