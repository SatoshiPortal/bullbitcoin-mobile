import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullReceiveSendButtons, BullText;
import 'package:bull_ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final (type, colors) in [
    (AppThemeType.light, AppColors.light),
    (AppThemeType.dark, AppColors.dark),
  ]) {
    testWidgets('both buttons are filled secondary actions ($type)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(type),
          home: Scaffold(
            body: BullReceiveSendButtons(
              receiveLabel: 'Receive',
              sendLabel: 'Send',
              onReceive: () {},
              onSend: () {},
            ),
          ),
        ),
      );
      final buttons = tester.widgetList<BullButton>(find.byType(BullButton));
      expect(buttons, hasLength(2));
      for (final button in buttons) {
        final scope = find.byWidget(button);
        final fill =
            tester
                    .widget<Container>(
                      find
                          .descendant(
                            of: scope,
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        final text = tester.widget<BullText>(
          find.descendant(of: scope, matching: find.byType(BullText)),
        );
        expect(fill.color, colors.secondary);
        expect(text.color, colors.onSecondary);
        expect(fill.border, isNull);
      }
    });
  }
}
