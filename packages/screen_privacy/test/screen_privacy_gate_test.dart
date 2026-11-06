import 'package:bull_ui/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_privacy/screen_privacy.dart';

const _labels = ScreenPrivacyGateLabels(
  message: 'protection unavailable',
  retry: 'retry',
  continueAnyway: 'continue anyway',
);

/// Answers each protection request with the next verdict, as
/// `enableScreenPrivacy` would.
class _FakeProtection {
  final List<bool> _verdicts;
  int calls = 0;

  _FakeProtection(this._verdicts);

  Future<bool> call() async => _verdicts[calls++];
}

Future<_FakeProtection> _pump(WidgetTester tester, List<bool> verdicts) async {
  final protection = _FakeProtection(verdicts);
  await tester.pumpWidget(
    wrapWithTheme(
      ScreenPrivacyGate(
        protect: protection.call,
        labels: _labels,
        builder: (context) => const Text('the secret'),
      ),
    ),
  );
  // Long enough for every automatic retry.
  await tester.pump(const Duration(seconds: 2));
  return protection;
}

void main() {
  testWidgets('shows the secret at once when protection succeeds', (
    tester,
  ) async {
    final protection = await _pump(tester, [true]);

    expect(find.text('the secret'), findsOneWidget);
    expect(find.text(_labels.message), findsNothing);
    expect(protection.calls, 1);
  });

  testWidgets('draws nothing while the verdict is pending', (tester) async {
    final protection = _FakeProtection([false, true]);
    await tester.pumpWidget(
      wrapWithTheme(
        ScreenPrivacyGate(
          protect: protection.call,
          labels: _labels,
          builder: (context) => const Text('the secret'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('the secret'), findsNothing);
    expect(find.text(_labels.message), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('the secret'), findsOneWidget);
  });

  testWidgets('an automatic retry that succeeds shows the secret', (
    tester,
  ) async {
    final protection = await _pump(tester, [false, true]);

    expect(find.text('the secret'), findsOneWidget);
    expect(find.text(_labels.message), findsNothing);
    expect(protection.calls, 2);
  });

  testWidgets('a refusal that outlasts the retries hides the secret behind '
      'the warning', (tester) async {
    final protection = await _pump(tester, [false, false, false]);

    expect(find.text('the secret'), findsNothing);
    expect(find.text(_labels.message), findsOneWidget);
    expect(find.text(_labels.retry), findsOneWidget);
    expect(find.text(_labels.continueAnyway), findsOneWidget);
    expect(protection.calls, 3);
  });

  testWidgets('Retry shows the secret once protection succeeds', (
    tester,
  ) async {
    final protection = await _pump(tester, [false, false, false, true]);

    await tester.tap(find.text(_labels.retry));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('the secret'), findsOneWidget);
    expect(find.text(_labels.message), findsNothing);
    expect(protection.calls, 4);
  });

  testWidgets('Retry that is refused again comes back to the warning', (
    tester,
  ) async {
    await _pump(tester, [false, false, false, false, false, false]);

    await tester.tap(find.text(_labels.retry));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('the secret'), findsNothing);
    expect(find.text(_labels.message), findsOneWidget);
  });

  testWidgets('Continue anyway shows the secret without protection', (
    tester,
  ) async {
    final protection = await _pump(tester, [false, false, false]);

    await tester.tap(find.text(_labels.continueAnyway));
    await tester.pump();

    expect(find.text('the secret'), findsOneWidget);
    expect(find.text(_labels.message), findsNothing);
    expect(protection.calls, 3);
  });
}
