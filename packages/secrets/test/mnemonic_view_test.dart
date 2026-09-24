import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:secrets/src/widgets/sealed_word.dart' show debugSealedTextOf;

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
      onFailure: (_, failure) => Text('failed: ${failure.runtimeType}'),
      placeholder: const Text('reading'),
    ),
  );

  testWidgets('renders the words once the read settles', (tester) async {
    final secret = await store(tester, wordsA);

    await tester.pumpWidget(hosted(secret));
    expect(find.text('reading'), findsOneWidget);
    await settle(tester);

    expect(sealed(wordsA.join(' ')), findsOneWidget);
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
      secret.widgets.mnemonicView(onFailure: (_, _) => const SizedBox()),
      secret.widgets.mnemonicView(
        onFailure: (_, _) => const SizedBox(),
        wordBuilder: (context, number, word) =>
            Row(children: [Text('$number.'), word]),
        layout: (context, words) => Column(children: words),
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
    }
  });
}

/// A word as it is painted: the widgets hold no `Text` to find, so the
/// package's own tests read the sealed render object instead.
Finder sealed(String text) => find.byElementPredicate(
  (e) => debugSealedTextOf(e) == text,
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
