import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import 'result_helpers.dart';

/// The sealed challenge: it shuffles, judges and reports, and the host styles tiles.
///
/// What is asserted is what a reader cannot check by eye — that a wrong tap resets rather than accumulating, that the verdict arrives only on a correct full sequence, and that the words stay out of the semantics tree. The API seal is structural and lives in `invariants_test.dart`.
///
/// Every call into the package goes through `tester.runAsync`: reads happen in an isolate, which a widget test's simulated clock never advances.
void main() {
  const words = [
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'about',
  ];

  late Secrets secrets;

  setUp(() {
    FakeSecureStoragePlatform().install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
  });

  Future<Secret> store(WidgetTester tester) async {
    late Secret secret;
    await tester.runAsync(() async {
      secret = ok(await secrets.import(words: words));
    });
    return secret;
  }

  Future<void> settle(WidgetTester tester, [int ms = 500]) async {
    await tester.runAsync(
      () => Future<void>.delayed(Duration(milliseconds: ms)),
    );
    await tester.pumpAndSettle();
  }

  var solved = 0;
  var mistakes = 0;
  var progress = <(int, int)>[];

  Widget hosted(Secret secret) => Directionality(
    textDirection: TextDirection.ltr,
    child: MnemonicChallenge(
      secret: secret,
      placeholder: const Text('reading'),
      onFailure: (_, failure) => Text('failed: ${failure.runtimeType}'),
      onSolved: () => solved++,
      onMistake: () => mistakes++,
      onProgress: (placed, total) => progress.add((placed, total)),
      // The tile carries its own word, so the test can tap by text without
      // the host ever having been handed the list.
      tileBuilder: (context, tile) => GestureDetector(
        onTap: tile.onTap,
        child: Text('${tile.position ?? 0}:${tile.word}'),
      ),
      layout: (context, tiles) => Column(children: tiles),
    ),
  );

  setUp(() {
    solved = 0;
    mistakes = 0;
    progress = <(int, int)>[];
  });

  testWidgets('shows every word, and none of them is placed yet', (
    tester,
  ) async {
    final secret = await store(tester);

    await tester.pumpWidget(hosted(secret));
    expect(find.text('reading'), findsOneWidget);
    await settle(tester);

    // 12 tiles, all unplaced. `abandon` appears eleven times, so the count is
    // what is asserted rather than the set.
    expect(find.byType(Text), findsNWidgets(12));
    expect(find.text('0:about'), findsOneWidget);
  });

  testWidgets('a wrong first tap resets instead of accumulating', (
    tester,
  ) async {
    final secret = await store(tester);

    await tester.pumpWidget(hosted(secret));
    await settle(tester);

    // `about` is word 12; tapping it first breaks the order.
    await tester.tap(find.text('0:about'));
    await settle(tester);

    expect(mistakes, 1);
    expect(solved, 0);
    expect(
      find.textContaining('1:'),
      findsNothing,
      reason: 'nothing stays placed after a mistake',
    );
    expect(progress.last, (0, 12));
  });

  testWidgets('the whole sequence in order solves it exactly once', (
    tester,
  ) async {
    final secret = await store(tester);

    await tester.pumpWidget(hosted(secret));
    await settle(tester);

    // Eleven `abandon`, then `about`. Any unplaced `abandon` is a correct
    // next tap, which is what lets this be driven without reading the order.
    for (var i = 0; i < 11; i++) {
      await tester.tap(find.text('0:abandon').first);
      await tester.pump();
    }
    expect(mistakes, 0, reason: 'every tap was a correct next word');
    expect(progress.last, (11, 12));

    await tester.tap(find.text('0:about'));
    await settle(tester);

    expect(solved, 1);
    expect(mistakes, 0);
  });

  testWidgets('the words stay out of the semantics tree', (tester) async {
    final handle = tester.ensureSemantics();
    final secret = await store(tester);

    await tester.pumpWidget(hosted(secret));
    await settle(tester);

    expect(find.bySemanticsLabel('0:about'), findsNothing);
    handle.dispose();
  });

  testWidgets('a failed read renders the host failure, not stored text', (
    tester,
  ) async {
    // An entry filed under a key it does not derive to: the read fails after
    // the handle exists, which is the only way this widget sees a failure.
    FakeSecureStoragePlatform(
      entries: {
        'seed_00000000':
            '{"mnemonicWords":["abandon","abandon","abandon","abandon",'
            '"abandon","abandon","abandon","abandon","abandon","abandon",'
            '"abandon","about"],"passphrase":null,"runtimeType":"mnemonic"}',
      },
    ).install();
    late Secret secret;
    await tester.runAsync(() async {
      secret = ok(
        await Secrets(
          scratchDirectory: () async => '/tmp',
        ).fetch(Fingerprint('00000000')),
      );
    });

    await tester.pumpWidget(hosted(secret));
    await settle(tester);

    expect(find.text('failed: SecretIdentityMismatchFailure'), findsOneWidget);
    expect(find.textContaining('abandon'), findsNothing);
    expect(solved, 0);
  });
}
