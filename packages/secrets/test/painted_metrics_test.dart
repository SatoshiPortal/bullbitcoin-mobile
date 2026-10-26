import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/src/widgets/painted_text.dart'
    show PaintedMnemonic, PaintedPassphrase, PaintedWord;

/// A host can measure what it places: its size after layout and the intrinsic sizes it can ask for at any width. None of it may follow the secret text, or measuring each word in a known font narrows it to a few BIP39 candidates.
void main() {
  // A proportional font from the app's own assets: the test font gives every glyph one width and would hide the leak.
  const style = TextStyle(fontFamily: 'Golos', fontSize: 20);

  setUpAll(() async {
    final loader = FontLoader('Golos')
      ..addFont(
        File(
          '../../assets/fonts/GolosText.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      );
    await loader.load();
  });

  /// Everything a host can read off the box under [width].
  Future<List<Object>> metricsOf(
    WidgetTester tester,
    Widget painted, {
    double width = 320,
  }) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: Align(
              alignment: Alignment.topLeft,
              child: KeyedSubtree(key: key, child: painted),
            ),
          ),
        ),
      ),
    );
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox) fail('nothing was laid out');
    return [
      box.size,
      box.getMinIntrinsicWidth(double.infinity),
      box.getMaxIntrinsicWidth(double.infinity),
      box.getMinIntrinsicHeight(100),
      box.getMaxIntrinsicHeight(width),
      box.getDryLayout(BoxConstraints(maxWidth: width)),
    ];
  }

  testWidgets('every word measures the same', (tester) async {
    final short = await metricsOf(tester, PaintedWord('act', style: style));
    final long = await metricsOf(tester, PaintedWord('abstract', style: style));
    final wide = await metricsOf(tester, PaintedWord('wagon', style: style));
    expect(long, short);
    expect(wide, short);
  });

  testWidgets('two mnemonics of one length measure the same', (tester) async {
    final a = await metricsOf(
      tester,
      PaintedMnemonic([...List.filled(11, 'act'), 'add'], style: style),
    );
    final b = await metricsOf(
      tester,
      PaintedMnemonic([...List.filled(11, 'abstract'), 'wagon'], style: style),
    );
    expect(b, a);
  });

  testWidgets('two passphrases of one length measure the same', (tester) async {
    final a = await metricsOf(tester, PaintedPassphrase('iiii', style: style));
    final b = await metricsOf(tester, PaintedPassphrase('WWWW', style: style));
    expect(b, a);
  });

  testWidgets('a cell holds the widest word without wrapping it', (
    tester,
  ) async {
    final metrics = await metricsOf(
      tester,
      PaintedWord('abstract', style: style),
    );
    final painter = TextPainter(
      text: const TextSpan(text: 'abstract', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    addTearDown(painter.dispose);
    final size = metrics.first as Size;
    expect(size.width, greaterThanOrEqualTo(painter.width));
    expect(size.height, painter.height);
  });
}
