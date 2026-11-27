import 'package:primitives/primitives.dart' show Ok;
import 'package:preferences/preferences.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:provisioning/provisioning.dart';
import 'package:onboarding/onboarding.dart';
import 'package:onboarding/setup.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';

class _Settings extends Mock implements Preferences {}

class _References extends Mock implements WalletInventory {}

class _Defaults extends Mock implements DefaultWalletProvisioning {}

void main() {
  testWidgets(
    'regtest setup does not claim Liquid software wallets are unavailable',
    (tester) async {
      final settings = _Settings();
      final references = _References();
      when(settings.readDeveloperEnvironment).thenAnswer(
        (_) async => Ok((
          environment: Environment.regtest,
          isSuperuser: true,
          isDevModeEnabled: true,
        )),
      );
      final provisioning = NetworkWalletProvisioning(
        settings: settings,
        inventory: references,
        defaults: _Defaults(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates:
              OnboardingLocalizations.localizationsDelegates,
          supportedLocales: OnboardingLocalizations.supportedLocales,
          home: Scaffold(
            body: OnboardingFeature.emptyNetworkWallets(
              provisioning: () => provisioning,
              refreshing: const Stream.empty(),
              initiallyRefreshing: false,
              onMainnet: () {},
              onImport: () {},
              onRecoverEncryptedVault: () {},
              onReady: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Liquid:'), findsNothing);
      expect(find.text('Regtest'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
