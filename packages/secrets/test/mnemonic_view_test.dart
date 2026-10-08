import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:secrets/src/widgets/painted_text.dart'
    show PaintedMnemonic, PaintedPassphrase, PaintedWord, debugPaintedTextOf;

/// The sealed display: it shows a secret's words and hands them to nobody.
///
/// What is asserted here is what a reader cannot check by eye — that the words stay out of the semantics tree, that a card handed a different secret never shows the previous one's, and that a failed read renders no stored text.
///
/// The API seal itself is structural: `MnemonicView` has no member that returns a mnemonic. `invariants_test.dart` checks that; searching the widget tree would prove nothing, since a test can always walk what it built.
///
/// Every call into the package goes through `tester.runAsync`: reads happen in an isolate, which the simulated clock of a widget test never advances.
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

  late FakeSecureStoragePlatform storage;
  late Secrets secrets;

  setUp(() {
    storage = FakeSecureStoragePlatform()..install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
  });

  Future<Secret> store(WidgetTester tester, List<String> words) async {
    late Secret secret;
    await tester.runAsync(() async {
      secret = (await secrets.import(words: words) as Ok<Secret, SecretFailure>)
          .value;
    });
    return secret;
  }

  /// Lets real time pass — for the isolate — then drains the frames the completed read scheduled.
  Future<void> settle(WidgetTester tester, [int ms = 500]) async {
    await tester.runAsync(
      () => Future<void>.delayed(Duration(milliseconds: ms)),
    );
    await tester.pumpAndSettle();
  }

  Widget hosted(Secret secret) => Directionality(
    textDirection: TextDirection.ltr,
    child: MnemonicView(
      secret: secret,
      failureBuilder: (_, failure, retry) => Column(
        children: [
          Text('failed: ${failure.runtimeType}'),
          GestureDetector(onTap: retry, child: const Text('retry')),
        ],
      ),
      placeholder: const Text('reading'),
    ),
  );

  testWidgets('renders the words once the read settles', (tester) async {
    final secret = await store(tester, wordsA);

    await tester.pumpWidget(hosted(secret));
    expect(find.text('reading'), findsOneWidget);
    await settle(tester);

    expect(sealed(wordsA.join(' ')), findsOneWidget);
    expect(find.byType(PaintedMnemonic), findsOneWidget);
  });

  testWidgets('the words stay out of the semantics tree', (tester) async {
    final handle = tester.ensureSemantics();
    final secret = await store(tester, wordsA);

    await tester.pumpWidget(hosted(secret));
    await settle(tester);

    expect(
      find.bySemanticsLabel(wordsA.join(' ')),
      findsNothing,
      reason: 'an accessibility service walks this tree',
    );
    handle.dispose();
  });

  testWidgets('the same secret is read once, not once per build', (
    tester,
  ) async {
    final secret = await store(tester, wordsA);

    await tester.pumpWidget(hosted(secret));
    await settle(tester);
    final afterFirst = storage.reads;

    await tester.pumpWidget(hosted(secret));
    await settle(tester);

    expect(storage.reads, afterFirst);
  });

  testWidgets('a different secret never shows the previous words', (
    tester,
  ) async {
    final a = await store(tester, wordsA);
    final b = await store(tester, wordsB);

    await tester.pumpWidget(hosted(a));
    await settle(tester);
    expect(sealed(wordsA.join(' ')), findsOneWidget);

    // The same element receives B — what an unkeyed, reordered list does.
    await tester.pumpWidget(hosted(b));
    await tester.pump();

    expect(
      sealed(wordsA.join(' ')),
      findsNothing,
      reason: "a retained FutureBuilder would keep A's words while B loads",
    );

    await settle(tester);
    expect(sealed(wordsB.join(' ')), findsOneWidget);
    expect(sealed(wordsA.join(' ')), findsNothing);
  });

  testWidgets('a failed read renders the failure, and no stored text', (
    tester,
  ) async {
    const sentinel = 'SYNTHETIC_STORED_SENTINEL';
    final secret = await store(tester, wordsA);
    // Corrupted after the handle exists. A present-but-unreadable value fails at once — no retry backoff, whose simulated timers a widget test cannot mix with the isolate's real ones.
    storage.entries['seed_${secret.id.hex}'] = '{"$sentinel": true}';

    await tester.pumpWidget(hosted(secret));
    await settle(tester);

    expect(find.textContaining('failed:'), findsOneWidget);
    expect(find.textContaining(sentinel), findsNothing);
    expect(sealed(wordsA.join(' ')), findsNothing);
  });

  testWidgets('a walk of the element tree finds no word and no passphrase', (
    tester,
  ) async {
    // What a host can do with plain Flutter: visit every element and read
    // each Text, RichText and EditableText. The words and the passphrase
    // are painted, so none of them is there — in the default sentence and
    // in a host's own word cells alike.
    late Secret secret;
    await tester.runAsync(() async {
      secret =
          (await secrets.import(words: wordsA, passphrase: 'hunter2')
                  as Ok<Secret, SecretFailure>)
              .value;
    });
    for (final view in [
      secret.widgets.mnemonicView(
        failureBuilder: (_, _, _) => const SizedBox(),
      ),
      secret.widgets.mnemonicView(
        failureBuilder: (_, _, _) => const SizedBox(),
        wordBuilder: (context, number, word) =>
            Row(children: [Text('$number.'), word]),
        layoutBuilder: (context, words) => Column(children: words),
      ),
    ]) {
      await tester.pumpWidget(
        Directionality(textDirection: TextDirection.ltr, child: view),
      );
      await settle(tester);

      final readable = walk(tester).join(' ');
      for (final word in {...wordsA, 'hunter2'}) {
        expect(readable, isNot(contains(word)));
      }
      expect(sealed('hunter2'), findsOneWidget, reason: 'painted, still shown');
      expect(find.byType(PaintedPassphrase), findsOneWidget);
      if (find.byType(PaintedMnemonic).evaluate().isEmpty) {
        expect(find.byType(PaintedWord), findsNWidgets(wordsA.length));
      }
    }
  });

  testWidgets('a failed read can be retried and its message stays accessible', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final secret = await store(tester, wordsA);
    storage.locked = true;

    await tester.pumpWidget(hosted(secret));
    expect(find.bySemanticsLabel('reading'), findsOneWidget);
    await settle(tester);
    expect(
      find.bySemanticsLabel('failed: KeystoreLockedFailure'),
      findsOneWidget,
    );
    expect(sealed(wordsA.join(' ')), findsNothing);

    final reads = storage.reads;
    storage.locked = false;
    await tester.pumpWidget(hosted(secret));
    await settle(tester);
    expect(storage.reads, reads, reason: 'same-id rebuilds do not retry');

    await tester.tap(find.text('retry'));
    await tester.pump();
    expect(find.text('reading'), findsOneWidget);
    await settle(tester);
    expect(sealed(wordsA.join(' ')), findsOneWidget);
    expect(find.textContaining('failed:'), findsNothing);
    expect(find.bySemanticsLabel(wordsA.join(' ')), findsNothing);
    semantics.dispose();
  });

  // A host builder runs with the FutureBuilder's own context, and
  // `FutureBuilder.future` is public: whatever the read yields there must
  // carry no word and no passphrase a host could read by name.
  testWidgets('the read a host builder can reach carries no word', (
    tester,
  ) async {
    late Secret secret;
    await tester.runAsync(() async {
      secret =
          (await secrets.import(words: wordsA, passphrase: 'hunter2')
                  as Ok<Secret, SecretFailure>)
              .value;
    });
    Future<Object?>? reached;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MnemonicView(
          secret: secret,
          failureBuilder: (_, _, _) => const SizedBox(),
          wordBuilder: (context, number, word) {
            reached ??= (context.widget as FutureBuilder).future;
            return word;
          },
        ),
      ),
    );
    await settle(tester);

    expect(reached, isNotNull);
    Object? value;
    await tester.runAsync(() async {
      value = ((await reached) as dynamic).value;
    });
    expect(() => (value as dynamic).words, throwsNoSuchMethodError);
    expect(() => (value as dynamic).passphrase, throwsNoSuchMethodError);
    expect(sealed('about'), findsOneWidget);
  });
}

/// A word as it is painted: the widgets hold no `Text` to find, so the
/// package's own tests read the sealed render object instead.
Finder sealed(String text) => find.byElementPredicate(
  (e) => debugPaintedTextOf(e) == text,
  description: 'sealed text "$text"',
);

/// Every string a host could read by walking its own element tree.
List<String> walk(WidgetTester tester) {
  final out = <String>[];
  void visit(Element e) {
    final w = e.widget;
    if (w is RichText) out.add(w.text.toPlainText());
    if (w is Text && w.data != null) out.add(w.data!);
    if (w is EditableText) out.add(w.controller.text);
    e.visitChildElements(visit);
  }

  tester.binding.rootElement!.visitChildElements(visit);
  return out;
}
