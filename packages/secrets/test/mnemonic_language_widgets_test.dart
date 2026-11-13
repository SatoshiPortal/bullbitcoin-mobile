import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Language, Mnemonic;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/src/widgets/painted_text.dart'
    show PaintedMnemonic, PaintedWord, debugPaintedTextOf;
import 'package:secrets/testing.dart';
import 'package:unorm_dart/unorm_dart.dart';

import 'result_helpers.dart';

void main() {
  const style = TextStyle(inherit: false, fontSize: 14);
  late Secrets secrets;

  setUp(() {
    FakeSecureStoragePlatform().install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
  });

  Future<Secret> store(
    WidgetTester tester,
    Language language, {
    bool restore = false,
  }) async {
    // Published BIP39 zero-entropy vector, never a funded wallet.
    final result = await tester.runAsync(
      () async => ok(
        await secrets.import(
          words: Mnemonic(List.filled(16, 0), language).words,
          language: language,
        ),
      ),
    );
    if (result == null) fail('import did not complete');
    if (!restore) return result;
    final restored = await tester.runAsync(() async {
      final backup = ok(await result.backup.recoverbull());
      ok(await secrets.trash(result.id));
      return ok(
        await secrets.recoverbull.restore(vault: backup.vault, key: backup.key),
      ).secret;
    });
    if (restored == null) fail("vault restoration did not complete");
    return restored;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pumpAndSettle();
  }

  Size publicCellSize(Language language) {
    final painter = TextPainter(textDirection: TextDirection.ltr);
    var width = 0.0;
    var height = 0.0;
    for (final word in language.list) {
      painter
        ..text = TextSpan(text: nfkd(word), style: style)
        ..layout();
      if (painter.width > width) width = painter.width;
      if (painter.height > height) height = painter.height;
    }
    painter.dispose();
    return Size(width, height);
  }

  Widget host(Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topLeft, child: child),
  );

  for (final language in Language.values) {
    for (final restore in [false, true]) {
      testWidgets(
        '${language.name} ${restore ? 'restored vault' : 'imported'} display uses its entire public wordlist',
        (tester) async {
          final secret = await store(tester, language, restore: restore);
          final semantics = tester.ensureSemantics();
          try {
            await tester.pumpWidget(
              host(
                secret.widgets.mnemonicView(
                  style: style,
                  failureBuilder: (_, _, _) => const Text('read failed'),
                  layoutBuilder: (_, words) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: words,
                  ),
                ),
              ),
            );
            await settle(tester);

            final cells = find.byType(PaintedWord);
            expect(cells, findsNWidgets(12));
            final expected = publicCellSize(language);
            for (final element in cells.evaluate()) {
              final box = element.renderObject as RenderBox;
              expect(box.size, expected);
              expect(box.getMinIntrinsicWidth(double.infinity), expected.width);
              expect(box.getMaxIntrinsicWidth(double.infinity), expected.width);
              expect(box.getDryLayout(const BoxConstraints()), expected);
            }
            final words = Mnemonic(
              List.filled(16, 0),
              language,
            ).words.map(nfkd).toList();
            expect(cells.evaluate().map(debugPaintedTextOf), words);
            for (final word in words) {
              expect(find.text(word), findsNothing);
              expect(find.bySemanticsLabel(word), findsNothing);
            }
            await tester.pumpWidget(
              host(
                secret.widgets.mnemonicView(
                  style: style,
                  failureBuilder: (_, _, _) => const Text('read failed'),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final sentence = find.byType(PaintedMnemonic);
            expect(sentence, findsOneWidget);
            expect(
              debugPaintedTextOf(sentence.evaluate().single),
              words.join(language.separator),
            );
            final gap = TextPainter(
              text: TextSpan(text: language.separator, style: style),
              textDirection: TextDirection.ltr,
            )..layout();
            final box = sentence.evaluate().single.renderObject as RenderBox;
            expect(
              box.getMaxIntrinsicWidth(double.infinity),
              12 * expected.width + 11 * gap.width,
            );
            gap.dispose();
          } finally {
            semantics.dispose();
          }
        },
      );
    }

    testWidgets('${language.name} sealed challenge sizes and verifies words', (
      tester,
    ) async {
      final secret = await store(tester, language);
      var solved = 0;
      var mistakes = 0;
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          host(
            secret.widgets.mnemonicChallenge(
              style: style,
              onSolved: () => solved++,
              onMistake: () => mistakes++,
              failureBuilder: (_, _, _) => const Text('read failed'),
              tileBuilder: (_, tile) =>
                  GestureDetector(onTap: tile.onTap, child: tile.word),
              layoutBuilder: (_, tiles) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: tiles,
              ),
            ),
          ),
        );
        await settle(tester);
        final expected = publicCellSize(language);
        for (final element in find.byType(PaintedWord).evaluate()) {
          expect((element.renderObject as RenderBox).size, expected);
        }
        final words = Mnemonic(
          List.filled(16, 0),
          language,
        ).words.map(nfkd).toList();
        Finder unplaced(String word) => find.byElementPredicate((element) {
          if (debugPaintedTextOf(element) != word) return false;
          var tappable = false;
          element.visitAncestorElements((ancestor) {
            if (ancestor.widget case GestureDetector(:final onTap)) {
              tappable = onTap != null;
              return false;
            }
            return true;
          });
          return tappable;
        });
        await tester.tap(unplaced(words.last).first);
        await tester.pump();
        expect(mistakes, 1);
        expect(solved, 0);
        for (final word in words) {
          expect(find.text(word), findsNothing);
          expect(find.bySemanticsLabel(word), findsNothing);
          await tester.tap(unplaced(word).first);
          await tester.pump();
        }
        await settle(tester);
        expect(solved, 1);
        expect(mistakes, 1);
      } finally {
        semantics.dispose();
      }
    });
  }
}
