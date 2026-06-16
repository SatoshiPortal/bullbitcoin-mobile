import 'package:bull_ui_catalogue/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Catalogue builds', (tester) async {
    await tester.pumpWidget(const BullUiCatalogue());
    expect(find.byType(BullUiCatalogue), findsOneWidget);
  });
}
