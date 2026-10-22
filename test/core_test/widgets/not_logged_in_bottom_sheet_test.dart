import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/not_logged_in_bottom_sheet.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final themeType in AppThemeType.values) {
    testWidgets(
      'the login label stays readable in the ${themeType.name} theme',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.themeData(themeType),
            home: const Scaffold(body: NotLoggedInBottomSheet()),
          ),
        );

        final button = tester.widget<BullButton>(find.byType(BullButton));
        expect(button.textColor, isNot(button.bgColor));
      },
    );
  }
}
