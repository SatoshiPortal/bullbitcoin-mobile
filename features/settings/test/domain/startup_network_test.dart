import 'package:electrum/setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:settings/setup.dart';
import 'package:settings/settings.dart';

class _Preferences extends Mock implements Preferences {}

class _Electrum extends Mock implements ElectrumDefaultsProvisioner {}

void main() {
  test('refuses without explicit unlock and developer consent', () async {
    final preferences = _Preferences();
    final electrum = _Electrum();
    for (final (unlocked, consent) in [(false, false), (true, false)]) {
      expect(
        await StartupNetwork.apply(
          preferences: preferences,
          electrum: electrum,
          network: NetworkEnv.testnet,
          superuserUnlocked: unlocked,
          developerConsent: consent,
          isProtected: () async => const Ok(false),
          hasWallets: () async => const Ok(false),
          listSecrets: () async => const Ok([]),
        ),
        isA<Err<void, SettingsFailure>>(),
      );
    }
    verifyZeroInteractions(preferences);
    verifyZeroInteractions(electrum);
  });

  test('persists flags before selecting the network', () async {
    final preferences = _Preferences();
    final electrum = _Electrum();
    when(() => preferences.setIsSuperuser(true))
        .thenAnswer((_) async => const Ok(null));
    when(() => preferences.setIsDevMode(true))
        .thenAnswer((_) async => const Ok(null));
    when(preferences.fetch).thenAnswer(
      (_) async => const Ok(
        SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          isSuperuser: true,
          isDevModeEnabled: true,
        ),
      ),
    );
    when(() => preferences.setEnvironment(Environment.testnet))
        .thenAnswer((_) async => const Ok(null));
    expect(
      await StartupNetwork.apply(
        preferences: preferences,
        electrum: electrum,
        network: NetworkEnv.testnet,
        superuserUnlocked: true,
        developerConsent: true,
        isProtected: () async => const Ok(false),
        hasWallets: () async => const Ok(false),
        listSecrets: () async => const Ok([]),
      ),
      isA<Ok<void, SettingsFailure>>(),
    );
    verifyInOrder([
      () => preferences.setIsSuperuser(true),
      () => preferences.setIsDevMode(true),
      () => preferences.fetch(),
      () => preferences.setEnvironment(Environment.testnet),
    ]);
  });

  test('stops before network selection when developer mode fails', () async {
    final preferences = _Preferences();
    final electrum = _Electrum();
    when(() => preferences.setIsSuperuser(true))
        .thenAnswer((_) async => const Ok(null));
    when(() => preferences.setIsDevMode(true))
        .thenAnswer((_) async => const Err(PreferencesWriteFailure()));
    final result = await StartupNetwork.apply(
      preferences: preferences,
      electrum: electrum,
      network: NetworkEnv.testnet,
      superuserUnlocked: true,
      developerConsent: true,
      isProtected: () async => const Ok(false),
      hasWallets: () async => const Ok(false),
      listSecrets: () async => const Ok([]),
    );
    expect(result, isA<Err<void, SettingsFailure>>());
    verifyNever(() => preferences.setEnvironment(Environment.testnet));
    verifyZeroInteractions(electrum);
  });

  for (final (protected, wallets) in [(true, false), (false, true)]) {
    test('does not alter existing custody: $protected $wallets', () async {
      final preferences = _Preferences();
      final electrum = _Electrum();
      final result = await StartupNetwork.apply(
        preferences: preferences,
        electrum: electrum,
        network: NetworkEnv.testnet,
        superuserUnlocked: true,
        developerConsent: true,
        isProtected: () async => Ok(protected),
        hasWallets: () async => Ok(wallets),
        listSecrets: () async => const Ok([]),
      );
      expect(result, isA<Err<void, SettingsFailure>>());
      verifyZeroInteractions(preferences);
      verifyZeroInteractions(electrum);
    });
  }
}
