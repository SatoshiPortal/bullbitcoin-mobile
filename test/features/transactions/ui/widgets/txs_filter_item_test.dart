import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:transactions/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('exposes its selected state within a 48 dp target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        home: Scaffold(
          body: Row(
            children: [
              TxsFilterItem(title: 'All', isSelected: true, onTap: () {}),
              TxsFilterItem(
                title: 'Send',
                isSelected: false,
                onTap: () => taps++,
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.text('All')),
      matchesSemantics(
        label: 'All',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.text('Send')),
      matchesSemantics(
        label: 'Send',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSize(find.byType(TxsFilterItem).first).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.text('Send'));
    expect(taps, 1);
    semantics.dispose();
  });
}
