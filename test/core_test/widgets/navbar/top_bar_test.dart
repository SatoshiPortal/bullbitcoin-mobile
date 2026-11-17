import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget bar) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.themeData(AppThemeType.light),
    home: Scaffold(body: bar),
  ),
);

void main() {
  testWidgets('names its back and close buttons', (tester) async {
    await _pump(tester, TopBar(title: 'Send', onBack: () {}, onAction: () {}));

    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
  });

  testWidgets('keeps a long title on one ellipsized header line', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const title = 'A very long localized screen title that cannot fit';
    await _pump(tester, TopBar(title: title, onBack: () {}));

    final text = tester.widget<Text>(find.text(title));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(
      tester.getSemantics(find.text(title)),
      matchesSemantics(label: title, isHeader: true),
    );
    semantics.dispose();
  });
}
