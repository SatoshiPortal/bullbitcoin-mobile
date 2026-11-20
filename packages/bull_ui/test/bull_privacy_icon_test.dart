import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('privacy exposes and renders the outlined shield glyph', (
    tester,
  ) async {
    expect(BullIcons.privacy, Icons.shield_outlined);
    await tester.pumpWidget(wrapWithTheme(const BullIcon(BullIcons.privacy)));
    expect(tester.widget<Icon>(find.byType(Icon)).icon, Icons.shield_outlined);
  });
}
