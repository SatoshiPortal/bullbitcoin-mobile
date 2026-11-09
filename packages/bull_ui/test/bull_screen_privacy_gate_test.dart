import 'dart:async';

import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

class _Host extends StatefulWidget {
  const _Host(this.answers);

  final List<Future<bool>> answers;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  var _calls = 0;
  late Future<bool> _protection = _ask();

  Future<bool> _ask() async => widget.answers[_calls++];

  @override
  Widget build(BuildContext context) => BullScreenPrivacyGate(
    protection: _protection,
    unavailableMessage: 'Capture protection unavailable',
    retryLabel: 'Retry',
    onRetry: () => setState(() {
      _protection = _ask();
    }),
    builder: (context) => const Text('the secret'),
  );
}

void main() {
  Future<void> pump(WidgetTester tester, List<Future<bool>> answers) async {
    await tester.pumpWidget(wrapWithTheme(_Host(answers)));
    await tester.pumpAndSettle();
  }

  testWidgets('draws the secret once capture blocking is confirmed', (
    tester,
  ) async {
    await pump(tester, [Future.value(true)]);

    expect(find.text('the secret'), findsOneWidget);
  });

  testWidgets('hides the secret when the platform refused, until a retry '
      'succeeds', (tester) async {
    await pump(tester, [Future.value(false), Future.value(true)]);

    expect(find.text('the secret'), findsNothing);
    expect(find.text('Capture protection unavailable'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('the secret'), findsOneWidget);
  });

  testWidgets('keeps the secret hidden while protection is pending', (
    tester,
  ) async {
    final protection = Completer<bool>();
    await pump(tester, [protection.future]);
    expect(find.text('the secret'), findsNothing);
    expect(find.text('Capture protection unavailable'), findsNothing);

    protection.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('the secret'), findsOneWidget);
  });

  testWidgets('keeps the secret hidden when protection throws', (tester) async {
    final protection = Completer<bool>();
    await pump(tester, [protection.future]);

    protection.completeError(StateError('platform unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('the secret'), findsNothing);
    expect(find.text('Capture protection unavailable'), findsOneWidget);
  });

  testWidgets('hides a previously visible secret for a new pending request', (
    tester,
  ) async {
    final protection = Completer<bool>();
    Future<void> show(Future<bool> future) => tester.pumpWidget(
      wrapWithTheme(
        BullScreenPrivacyGate(
          protection: future,
          unavailableMessage: 'Capture protection unavailable',
          retryLabel: 'Retry',
          onRetry: () {},
          builder: (_) => const Text('the secret'),
        ),
      ),
    );
    await show(Future.value(true));
    await tester.pumpAndSettle();
    expect(find.text('the secret'), findsOneWidget);

    await show(protection.future);
    expect(find.text('the secret'), findsNothing);
    protection.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('the secret'), findsNothing);
    expect(find.text('Capture protection unavailable'), findsOneWidget);
  });
}
