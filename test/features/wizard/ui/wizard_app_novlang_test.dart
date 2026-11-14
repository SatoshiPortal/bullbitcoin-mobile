import 'package:bb_mobile/features/wizard/ui/wizard_app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The wizard builds its own MaterialApp before the main app exists, so it has
/// to compose the store vocabulary itself.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const real =
      'Sovereign self custody Bitcoin wallet and Bitcoin-only exchange service.';
  const apple =
      'Sovereign self custody Bitcoin wallet and Bitcoin-only services.';

  testWidgets('shows the App Store vocabulary on iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(WizardApp(onDone: (_) {}));
      await tester.pumpAndSettle();

      expect(find.text(apple), findsOneWidget);
      expect(find.text(real), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('keeps the real words on Android', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(WizardApp(onDone: (_) {}));
      await tester.pumpAndSettle();

      expect(find.text(real), findsOneWidget);
      expect(find.text(apple), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
