import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('core compatibility facade matches BullSnackBar', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [testBullTheme]),
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    SnackBarUtils.showSnackBar(context, 'message');
    await tester.pump(const Duration(milliseconds: 300));
    final facadeContainer = tester.widget<Container>(
      find.byType(Container).last,
    );
    final facadeDecoration = facadeContainer.decoration as BoxDecoration;
    SnackBarUtils.dismiss();
    await tester.pumpAndSettle();

    BullSnackBar.show(context, message: 'message');
    await tester.pump(const Duration(milliseconds: 300));
    final directContainer = tester.widget<Container>(
      find.byType(Container).last,
    );
    final directDecoration = directContainer.decoration as BoxDecoration;

    expect(facadeContainer.padding, directContainer.padding);
    expect(facadeDecoration.color, directDecoration.color);
    expect(facadeDecoration.borderRadius, directDecoration.borderRadius);
    BullSnackBar.dismiss();
    await tester.pumpAndSettle();
  });
}
