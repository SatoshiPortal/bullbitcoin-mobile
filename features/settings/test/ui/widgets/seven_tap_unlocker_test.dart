import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show bullUiLocalizationsDelegate;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:settings/settings.dart';
import 'package:settings/testing.dart' show settingsTestLocalizationsDelegates;

void main() {
  testWidgets('requires seven taps and exposes a stable identifier', (
    tester,
  ) async {
    var unlocked = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: const [
          bullUiLocalizationsDelegate,
          ...settingsTestLocalizationsDelegates,
        ],
        home: Scaffold(
          body: SevenTapUnlocker(
            semanticsIdentifier: 'wizard.superuser.unlock',
            onRequiredTaps: () => unlocked++,
            tapsReachedMessage: 'Unlocked',
            child: const Text('Logo'),
          ),
        ),
      ),
    );
    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byType(SevenTapUnlocker)).identifier,
      'wizard.superuser.unlock',
    );
    for (var tap = 0; tap < 6; tap++) {
      await tester.tap(find.text('Logo'));
      await tester.pump();
    }
    expect(unlocked, 0);
    await tester.tap(find.text('Logo'));
    await tester.pump();
    expect(unlocked, 1);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    semantics.dispose();
  });
}
