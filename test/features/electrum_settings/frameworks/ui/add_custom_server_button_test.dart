import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/widgets/add_custom_server_button.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('the add button keeps its name and its tap action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: AddCustomServerButton()),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Add Custom Server')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    semantics.dispose();
  });
}
