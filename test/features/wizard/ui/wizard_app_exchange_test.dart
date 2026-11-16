import 'package:bb_mobile/features/wizard/ui/screens/wizard_screen.dart';
import 'package:bb_mobile/features/wizard/ui/wizard_app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The App Store does not allow the exchange: the wizard must not offer it on
/// iOS, where only a superuser can turn it on later from the settings.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (platform, allowed) in [
    (TargetPlatform.iOS, false),
    (TargetPlatform.android, true),
  ]) {
    testWidgets('offers the exchange on ${platform.name}: $allowed', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await tester.pumpWidget(WizardApp(onDone: (_) {}));
        await tester.pumpAndSettle();

        final screen = tester.widget<WizardScreen>(find.byType(WizardScreen));
        expect(screen.exchangeAllowed, allowed);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
