import '../../fixtures.dart';

import 'package:network/src/electrum_settings/ui/widgets/add_custom_server_button.dart';
import 'package:network/generated/l10n/network_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('the add button keeps its name and its tap action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: networkTestTheme(),
        localizationsDelegates: networkTestLocalizationsDelegates,
        supportedLocales: NetworkLocalizations.supportedLocales,
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
