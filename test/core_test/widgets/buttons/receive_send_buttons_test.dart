import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/themes/colors.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/buttons/receive_send_buttons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final (type, colors) in [
    (AppThemeType.light, AppColors.light),
    (AppThemeType.dark, AppColors.dark),
  ]) {
    testWidgets('both buttons are painted in the action button roles ($type)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(type),
          home: Scaffold(
            body: ReceiveSendButtons(
              receiveLabel: 'Receive',
              sendLabel: 'Send',
              onReceive: () {},
              onSend: () {},
            ),
          ),
        ),
      );
      final buttons = tester.widgetList<BBButton>(find.byType(BBButton));
      expect(buttons, hasLength(2));
      for (final button in buttons) {
        expect(button.bgColor, colors.actionButton);
        expect(button.textColor, colors.onActionButton);
        expect(button.outlined, isTrue);
        expect(button.borderColor, colors.actionButtonOutline);
      }
    });
  }
}
