import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import 'result_helpers.dart';

/// The sealed challenge: it shuffles, judges and reports, and the host styles tiles it cannot read.
///
/// What is asserted is what a reader cannot check by eye — that a wrong tap resets rather than accumulating, that the verdict arrives only on a correct full sequence, that a secret swapped mid-read never becomes the answer key, and that the words stay out of the semantics tree. The API seal is structural and lives in `invariants_test.dart`.
///
/// The host never sees a word, so these tests tap through the rendered text — which is exactly what a host cannot do without walking the tree.
void main() {
  const wordsA = [
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
  const wordsB = [
    'legal',
    'winner',
    'thank',
    'year',
    'wave',
    'sausage',
    'worth',
    'useful',
    'legal',
    'winner',
    'thank',
    'yellow',
  ];

  late Secrets secrets;

  setUp(() {
    FakeSecureStoragePlatform().install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
  });

  Future<Secret> store(WidgetTester tester, List<String> words) async {
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

  setUp(() {
    solved = 0;
    mistakes = 0;
    progress = <(int, int)>[];
  });

  /// A tile renders its position and the word widget side by side, so the
  /// test can find a word by text and a placed tile by its number.
  Widget hosted(Secret secret) => Directionality(
    textDirection: TextDirection.ltr,
    child: MnemonicChallenge(
      secret: secret,
      placeholder: const Text('reading'),
      onFailure: (_, failure) => Text('failed: ${failure.runtimeType}'),
      onSolved: () => solved++,
      onMistake: () => mistakes++,
      onProgress: (placed, total) => progress.add((placed, total)),
      tileBuilder: (context, tile) => GestureDetector(
        onTap: tile.onTap,
        child: Row(children: [Text('#${tile.position ?? 0}'), tile.word]),
      ),
      layout: (context, tiles) => Column(children: tiles),
    ),
  );

  testWidgets('shows every word, and none of them is placed yet', (
    tester,
  ) async {
    final secret = await store(tester, wordsA);

    await tester.pumpWidget(hosted(secret));
    expect(find.text('reading'), findsOneWidget);
    await settle(tester);

    expect(find.text('abandon'), findsNWidgets(11));
    expect(find.text('about'), findsOneWidget);
    expect(find.text('#0'), findsNWidgets(12));
  });

  testWidgets('the tile hands the host a widget, not the word', (tester) async {
    // The structural half is in `invariants_test.dart`; this is the runtime
    // half: the widget the host gets is not a `Text` it could read `.data` on.
    final secret = await store(tester, wordsA);
    Widget? handed;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MnemonicChallenge(
          secret: secret,
          onFailure: (_, _) => const SizedBox(),
          onSolved: () {},
          onMistake: () {},
          tileBuilder: (context, tile) {
            handed ??= tile.word;
            return tile.word;
          },
          layout: (context, tiles) => Column(children: tiles),
        ),
      ),
    );
    await settle(tester);

    expect(handed, isNotNull);
    expect(handed, isNot(isA<Text>()));
    expect(handed.runtimeType.toString(), 'SealedWord');
  });

  testWidgets('a wrong first tap resets instead of accumulating', (
    tester,
  ) async {
    final secret = await store(tester, wordsA);

    await tester.pumpWidget(hosted(secret));
    await settle(tester);

    // `about` is word 12; tapping it first breaks the order.
    await tester.tap(find.text('about'));
    await settle(tester);

    expect(mistakes, 1);
    expect(solved, 0);
    expect(find.text('#1'), findsNothing, reason: 'nothing stays placed');
    expect(progress.last, (0, 12));
  });

  testWidgets('the whole sequence in order solves it exactly once', (
    tester,
  ) async {
    final secret = await store(tester, wordsA);

    await tester.pumpWidget(hosted(secret));
    await settle(tester);

    // Eleven `abandon`, then `about`. Any unplaced `abandon` is a correct
    // next tap, which is what lets this be driven without knowing the order.
    // Each of the eleven `abandon` tiles once, in rendered order: a placed
    // tile's `onTap` is null, so `.at(i)` visits each distinct tile exactly
    // once whatever the shuffle produced.
    for (var i = 0; i < 11; i++) {
      await tester.tap(find.text('abandon').at(i));
      await tester.pump();
    }
    expect(mistakes, 0, reason: 'every tap was a correct next word');
    expect(progress.last, (11, 12));

    await tester.tap(find.text('about'));
    await settle(tester);

    expect(solved, 1);
    expect(mistakes, 0);
  });

  testWidgets('a secret swapped mid-read never becomes the answer key', (
    tester,
  ) async {
    // A2 (Codex, 2026-09-16): the read outlives an `await`. Handed secret B
    // before A's read returns, the widget must show B and judge against B —
    // whichever read finishes last.
    final a = await store(tester, wordsA);
    final b = await store(tester, wordsB);

    await tester.pumpWidget(hosted(a));
    await tester.pump(); // A's read is in flight
    await tester.pumpWidget(hosted(b));
    await settle(tester);

    expect(find.text('abandon'), findsNothing);
    expect(find.text('legal'), findsNWidgets(2));

    // And the running check is B's: B's first word is `legal`; `about` is
    // not in B at all, so a first tap on any B word other than `legal`
    // resets — which proves the answer key is B's, not A's.
    await tester.tap(find.text('yellow'));
    await settle(tester);
    expect(mistakes, 1);
    expect(solved, 0);
  });

  testWidgets('the words stay out of the semantics tree', (tester) async {
    final handle = tester.ensureSemantics();
    final secret = await store(tester, wordsA);

    await tester.pumpWidget(hosted(secret));
    await settle(tester);

    expect(find.bySemanticsLabel('about'), findsNothing);
    handle.dispose();
  });

  testWidgets('a failed read renders the host failure, not stored text', (
    tester,
  ) async {
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
    expect(find.text('abandon'), findsNothing);
    expect(solved, 0);
  });
}
