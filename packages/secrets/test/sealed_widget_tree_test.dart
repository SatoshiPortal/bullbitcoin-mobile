import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

/// A host walking its own element tree reaches every public widget field below it. The sealed widgets must leave nothing there that resolves to the words: this walks the tree as any host could, with no `src/` import, and awaits every future it finds.
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
  const passphrase = 'public-test-passphrase';

  for (final challenge in [false, true]) {
    testWidgets(
      'the ${challenge ? 'challenge' : 'view'} publishes no future of the words',
      (tester) async {
        FakeSecureStoragePlatform().install();
        final secrets = Secrets(scratchDirectory: () async => '/tmp');
        late Secret secret;
        await tester.runAsync(() async {
          final result = await secrets.import(
            words: words,
            passphrase: passphrase,
          );
          secret = (result as Ok<Secret, SecretFailure>).value;
        });
        late BuildContext host;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) {
                host = context;
                return challenge
                    ? secret.widgets.mnemonicChallenge(
                        tileBuilder: (_, tile) => tile.word,
                        layoutBuilder: (_, tiles) => Wrap(children: tiles),
                        onSolved: () {},
                        onMistake: () {},
                        failureBuilder: (_, _, _) => const SizedBox.shrink(),
                      )
                    : secret.widgets.mnemonicView(
                        failureBuilder: (_, _, _) => const SizedBox.shrink(),
                      );
              },
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)),
        );
        await tester.pumpAndSettle();

        final futures = <Future<dynamic>>[];
        void inspect(Element element) {
          if (element.widget case FutureBuilder(:final future?)) {
            futures.add(future);
          }
          element.visitChildElements(inspect);
        }

        host.visitChildElements(inspect);
        final leaked = <Object?>[];
        await tester.runAsync(() async {
          for (final future in futures) {
            final dynamic result = await future;
            if (result is Ok) leaked.add(result.value);
          }
        });
        expect(leaked, isEmpty);
      },
    );
  }
}
