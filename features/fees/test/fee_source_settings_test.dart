import 'dart:ui' show Tristate;

import 'package:bull_ui/testing.dart';
import 'package:fees/fees.dart';
import 'package:fees_feature/fees_feature.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

void main() {
  testWidgets('opens the mounted route and selects the saved fee source', (
    tester,
  ) async {
    final fees = _Fees();
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_settings(fees));
      expect(fees.reads, 0);

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();

      expect(find.text('Bitcoin fee source'), findsOneWidget);
      expect(_selected(tester, 'Electrum'), Tristate.isTrue);

      await tester.tap(find.text('Mempool'));
      await tester.pumpAndSettle();

      expect(fees.source, FeeSource.mempool);
      expect(_selected(tester, 'Mempool'), Tristate.isTrue);

      await tester.tap(find.text('Electrum'));
      await tester.pumpAndSettle();
      expect(fees.source, FeeSource.electrum);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('keeps the current selection and retries a failed save', (
    tester,
  ) async {
    final fees = _Fees(failWrite: true);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_settings(fees));
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mempool'));
      await tester.pumpAndSettle();

      expect(fees.source, FeeSource.electrum);
      expect(_selected(tester, 'Electrum'), Tristate.isTrue);
      expect(find.textContaining('Could not save'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(fees.source, FeeSource.mempool);
      expect(_selected(tester, 'Mempool'), Tristate.isTrue);
      expect(find.textContaining('Could not save'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('exposes a retry if loading the fee source fails', (
    tester,
  ) async {
    final fees = _Fees(failRead: true);
    await tester.pumpWidget(_settings(fees));
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    expect(find.text('Could not load the fee source.'), findsOneWidget);
    expect(find.text('Electrum'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Electrum'), findsOneWidget);
    expect(find.text('Could not load the fee source.'), findsNothing);
  });

  test('localizes the settings entry using the language and fallback', () {
    expect(FeesNavigation.settingsTitle('fr_CA'), 'Source des frais Bitcoin');
    expect(
      FeesNavigation.settingsTitle('es-MX'),
      'Fuente de comisiones de Bitcoin',
    );
    expect(FeesNavigation.settingsTitle('de'), 'Bitcoin fee source');
  });
}

Tristate _selected(WidgetTester tester, String label) => tester
    .getSemantics(find.bySemanticsLabel(label))
    .flagsCollection
    .isSelected;

Widget _settings(Fees fees) {
  final feature = FeesFeature.mount(fees: () => fees);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => FeesNavigation.openSettings(context),
            child: const Text('Open settings'),
          ),
        ),
      ),
      ...feature.routes,
    ],
  );
  addTearDown(router.dispose);
  return MaterialApp.router(
    theme: ThemeData(extensions: testBullExtensions),
    routerConfig: router,
  );
}

class _Fees implements Fees {
  FeeSource source = FeeSource.electrum;
  bool failRead;
  bool failWrite;
  int reads = 0;

  _Fees({this.failRead = false, this.failWrite = false});

  @override
  Future<Result<FeeSource, FeesFailure>> readSource() async {
    reads++;
    if (failRead) {
      failRead = false;
      return const Err(FeeSourceReadFailure());
    }
    return Ok(source);
  }

  @override
  Future<Result<void, FeesFailure>> saveSource(FeeSource source) async {
    if (failWrite) {
      failWrite = false;
      return const Err(FeeSourceWriteFailure());
    }
    this.source = source;
    return const Ok(null);
  }

  @override
  Future<Result<FeeOptions, FeesFailure>> estimate(
    Network network, {
    FeeSource? source,
  }) => throw StateError('Unexpected estimate');
}
