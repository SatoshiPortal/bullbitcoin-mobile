import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows progress in the button and ignores taps while loading', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        home: Scaffold(
          body: BBButton.big(
            label: 'Working',
            onPressed: () => taps++,
            bgColor: Colors.red,
            textColor: Colors.white,
            loading: true,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Working'), warnIfMissed: false);
    expect(taps, 0);
  });
}
