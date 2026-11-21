import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_editor/label_editor.dart';

void main() {
  testWidgets('the delete icon has a named 48 dp target', (tester) async {
    var deletes = 0;
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        wrapWithTheme(LabelChip(label: 'Coffee', onDelete: () => deletes++)),
      );

      final delete = find.bySemanticsLabel('Delete');
      expect(delete, findsOneWidget);
      expect(tester, meetsGuideline(androidTapTargetGuideline));
      expect(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.tap(delete);
      expect(deletes, 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('a short suggestion has a named 48 dp target', (tester) async {
    var selections = 0;
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        wrapWithTheme(LabelChip(label: 'A', onTap: () => selections++)),
      );

      final suggestion = find.bySemanticsLabel('A');
      expect(suggestion, findsOneWidget);
      expect(tester, meetsGuideline(androidTapTargetGuideline));
      expect(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.tap(find.byType(LabelChip));
      expect(selections, 1);
    } finally {
      semantics.dispose();
    }
  });
}
