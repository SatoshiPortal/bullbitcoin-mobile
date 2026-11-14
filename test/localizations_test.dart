import 'package:bb_mobile/localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('French inputs use standalone Material localizations', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: Scaffold(body: TextField()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final context = tester.element(find.byType(TextField));
    expect(MaterialLocalizations.of(context).copyButtonLabel, 'Copier');
  });
}
