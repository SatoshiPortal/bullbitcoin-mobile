import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps the title centered with a wide trailing action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 80,
            child: TopBar(
              title: 'Send',
              onBack: () {},
              action: const SizedBox(width: 120, child: Text('Finish later')),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getCenter(find.text('Send')).dx,
      closeTo(tester.getCenter(find.byType(TopBar)).dx, 0.1),
    );
  });
}
