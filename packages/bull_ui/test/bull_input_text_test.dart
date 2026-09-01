import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  testWidgets('shows its label and validation message', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        BullInputText(
          value: '',
          label: 'Name',
          errorText: 'Name is required',
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Name is required'), findsOneWidget);
  });
}
