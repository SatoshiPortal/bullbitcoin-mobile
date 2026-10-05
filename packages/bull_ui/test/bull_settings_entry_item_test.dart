import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  testWidgets('long titles wrap without hiding the action', (tester) async {
    const label = 'Recover with Data Recovery Words';
    var taps = 0;
    await tester.pumpWidget(
      wrapWithTheme(
        Center(
          child: SizedBox(
            width: 280,
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: BullSettingsEntryItem(
                icon: Icons.restore,
                title: label,
                titleMaxLines: null,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      ),
    );
    final text = find.text(label);
    expect(
      tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
      isFalse,
    );
    expect(
      tester.getSize(find.byType(BullSettingsEntryItem)).height,
      greaterThan(56),
    );
    await tester.tap(text);
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}
