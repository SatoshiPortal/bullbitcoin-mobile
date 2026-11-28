import 'dart:async';

import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_ui/app_theme.dart';
import 'package:onboarding/onboarding.dart' show OnboardingLocalizations;
import 'package:primitives/primitives.dart' show Err, NetworkEnv, Ok;
import 'package:preferences/preferences.dart';
import 'package:provisioning/provisioning.dart';
import 'package:onboarding/setup.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _Settings extends Mock implements Preferences {}

class _References extends Mock implements WalletInventory {}

class _Defaults extends Mock implements DefaultWalletProvisioning {}

void main() {
  testWidgets('regtest retries and reuses the chosen fingerprint once', (
    tester,
  ) async {
    FakeSecureStoragePlatform().install();
    final secrets = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => '/tmp',
    );
    final fixture = await tester.runAsync(() async {
      final result = await secrets.import(
        words: bip39.Mnemonic(
          List.filled(16, 0),
          bip39.Language.english,
        ).sentence.split(' '),
        language: bip39.Language.english,
      );
      return (result as Ok<Secret, SecretFailure>).value;
    });
    if (fixture == null) throw StateError('Fixture secret missing');
    registerFallbackValue(fixture);
    final settings = _Settings();
    var settingsReads = 0;
    when(settings.readDeveloperEnvironment).thenAnswer((_) async {
      if (settingsReads++ == 0) return const Err(PreferencesReadFailure());
      return const Ok((
        environment: Environment.regtest,
        isSuperuser: true,
        isDevModeEnabled: true,
      ));
    });
    final inventory = _References();
    when(inventory.referencedFingerprints)
        .thenAnswer((_) async => Ok([fixture.id]));
    final defaults = _Defaults();
    var attempts = 0;
    when(
      () => defaults.execute(
        expectedNetwork: NetworkEnv.regtest,
        secret: any(named: 'secret'),
      ),
    ).thenAnswer(
      (_) async => attempts++ == 0
          ? const Err(DefaultWalletBackupRequiredFailure())
          : const Ok([]),
    );
    var ready = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: OnboardingLocalizations.localizationsDelegates,
        supportedLocales: OnboardingLocalizations.supportedLocales,
        home: Scaffold(
          body: OnboardingFeature.emptyNetworkWallets(
            provisioning: () => NetworkWalletProvisioning(
              settings: settings,
              inventory: inventory,
              defaults: defaults,
              secrets: secrets,
            ),
            refreshing: const Stream.empty(),
            initiallyRefreshing: false,
            onMainnet: () => fail('Unexpected Mainnet redirect'),
            onImport: () {},
            onRecoverEncryptedVault: () {},
            onReady: () => ready++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final loc = OnboardingLocalizations.of(
      tester.element(find.byType(Scaffold)),
    );
    expect(find.text(loc.walletLoadFailed), findsOneWidget);
    await tester.tap(find.text(loc.retry));
    await tester.pumpAndSettle();
    expect(find.text(loc.electrumRegtest), findsOneWidget);
    final reuse = find.text(
      '${loc.walletDetailsWalletFingerprintLabel}: ${fixture.id.hex}',
    );
    await tester.tap(reuse);
    await tester.pumpAndSettle();
    expect(find.text(loc.networkWalletBackupRequired), findsOneWidget);
    expect(ready, 0);
    await tester.tap(reuse);
    await tester.pumpAndSettle();
    expect(ready, 1);
    await tester.tap(reuse);
    await tester.pumpAndSettle();
    expect(ready, 1);
    final used = verify(
      () => defaults.execute(
        expectedNetwork: NetworkEnv.regtest,
        secret: captureAny(named: 'secret'),
      ),
    ).captured;
    expect(used.map((secret) => (secret as Secret).id), [
      fixture.id,
      fixture.id,
    ]);
  });

  testWidgets(
    'the view owns one setup session and cancels its refresh listener',
    (tester) async {
      final settings = _Settings();
      final references = _References();
      when(settings.readDeveloperEnvironment).thenAnswer(
        (_) async => Ok((
          environment: Environment.mainnet,
          isSuperuser: false,
          isDevModeEnabled: false,
        )),
      );
      final provisioning = NetworkWalletProvisioning(
        settings: settings,
        inventory: references,
        defaults: _Defaults(),
      );
      var canceled = false;
      final refreshing = StreamController<bool>(
        onCancel: () => canceled = true,
      );
      addTearDown(refreshing.close);
      var creations = 0;
      final view = OnboardingFeature.emptyNetworkWallets(
        provisioning: () {
          creations++;
          return provisioning;
        },
        refreshing: refreshing.stream,
        initiallyRefreshing: false,
        onMainnet: () {},
        onImport: () {},
        onRecoverEncryptedVault: () {},
        onReady: () {},
      );
      Widget app() => MaterialApp(home: view);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      expect(creations, 1);
      verify(settings.readDeveloperEnvironment).called(1);
      verifyZeroInteractions(references);
      expect(canceled, isFalse);
      refreshing.add(false);
      refreshing.add(true);
      refreshing.add(false);
      await tester.pumpAndSettle();
      verify(settings.readDeveloperEnvironment).called(1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(canceled, isTrue);
    },
  );
}
