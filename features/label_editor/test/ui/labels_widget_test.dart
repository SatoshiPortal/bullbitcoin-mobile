import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_editor/label_editor.dart';
import 'package:labels/labels.dart';

void main() {
  Label label(String text) => Label.tx(id: 1, transactionId: 'tx', label: text);

  testWidgets('a long label is shortened to the limit', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        LabelsWidget(
          labels: [label('83c21ec56e5fa425fdf6319ad4f87ec5')],
          maxCharacters: 12,
        ),
      ),
    );
    expect(find.text('83c21ec56e5f…'), findsOneWidget);
  });

  testWidgets('a label within the limit is shown whole', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(LabelsWidget(labels: [label('Coffee')], maxCharacters: 12)),
    );
    expect(find.text('Coffee'), findsOneWidget);
  });

  testWidgets('without a limit the label is shown whole', (tester) async {
    const text = '83c21ec56e5fa425fdf6319ad4f87ec5';
    await tester.pumpWidget(wrapWithTheme(LabelsWidget(labels: [label(text)])));
    expect(find.text(text), findsOneWidget);
  });
}
