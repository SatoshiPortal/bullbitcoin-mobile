import 'package:onboarding/src/presentation/network_wallet_setup_failure_l10n.dart';
import 'package:onboarding/onboarding.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:provisioning/provisioning.dart';
import 'package:secrets/secrets.dart';

class _Settings extends Mock implements DeveloperEnvironmentReader {}

class _Inventory extends Mock implements WalletInventory {}

class _Defaults extends Mock implements DefaultWalletProvisioning {}

void main() {
  testWidgets(
    'seed-only reuse explains that the wallet has no recovery phrase',
    (tester) async {
      const failure = NetworkWalletSetupSecretFailure(
        DefaultWalletSecretRefusal.nonMnemonic,
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates:
              OnboardingLocalizations.localizationsDelegates,
          supportedLocales: OnboardingLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Text(failure.toTranslated(context)),
          ),
        ),
      );
      final l10n = await OnboardingLocalizations.delegate.load(
        const Locale('en'),
      );
      expect(
        find.text(l10n.networkWalletReuseNoRecoveryPhrase),
        findsOneWidget,
      );
      expect(find.text(l10n.walletLoadFailed), findsNothing);
    },
  );

  testWidgets('backup requirement has its dedicated message', (tester) async {
    final settings = _Settings();
    final defaults = _Defaults();
    when(() => settings.readDeveloperEnvironment()).thenAnswer(
      (_) async => const Ok((
        environment: Environment.regtest,
        isSuperuser: true,
        isDevModeEnabled: true,
      )),
    );
    when(
      () => defaults.execute(expectedNetwork: NetworkEnv.regtest),
    ).thenAnswer((_) async => const Err(DefaultWalletBackupRequiredFailure()));
    final result = await NetworkWalletProvisioning(
      settings: settings,
      inventory: _Inventory(),
      defaults: defaults,
    ).create(network: NetworkEnv.regtest);
    final failure = (result as Err<void, NetworkWalletSetupFailure>).failure;
    expect(failure, isA<NetworkWalletSetupBackupRequiredFailure>());
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: OnboardingLocalizations.localizationsDelegates,
        supportedLocales: OnboardingLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Text(failure.toTranslated(context)),
        ),
      ),
    );
    final l10n = await OnboardingLocalizations.delegate.load(
      const Locale('en'),
    );
    expect(find.text(l10n.networkWalletBackupRequired), findsOneWidget);
    expect(find.text(l10n.walletLoadFailed), findsNothing);
  });
}
