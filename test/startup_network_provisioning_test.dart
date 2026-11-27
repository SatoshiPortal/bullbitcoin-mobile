import 'package:electrum/setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart'
    show Environment, Preferences, SettingsEntity;
import 'package:primitives/primitives.dart';
import 'package:provisioning/provisioning.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:settings/settings.dart';
import 'package:settings/setup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wizard/wizard.dart';

class _Preferences extends Mock implements Preferences {}

class _Electrum extends Mock implements ElectrumDefaultsProvisioner {}

class _Inventory implements WalletInventory {
  final List<WalletRegistration> wallets = [];

  @override
  Future<bool> mayNotifyArk(Fingerprint parent) async => false;

  @override
  Future<Result<List<Fingerprint>, SecretFailure>>
  referencedFingerprints() async => const Ok([]);

  @override
  Future<Result<WalletRegistration, SecretFailure>> readWallet(
    String id,
  ) async => Ok(wallets.singleWhere((wallet) => wallet.id == id));

  @override
  Future<Result<WalletSelection, SecretFailure>> walletsForNetwork(
    Network network,
  ) async => Ok(
    walletSelectionForTesting(
      wallets.where((wallet) => wallet.network == network).toList(),
    ),
  );
}

class _Accounts implements WalletProvisioning {
  final _Inventory inventory;
  final List<Network> created = [];

  _Accounts(this.inventory);

  @override
  Future<Result<void, WalletProvisioningFailure>> resume() async =>
      const Ok(null);

  @override
  Future<Result<String, WalletProvisioningFailure>> createDefault(
    Secret secret,
    Network network, {
    DateTime? birthday,
  }) async {
    created.add(network);
    final id = network.toString();
    inventory.wallets.add(
      walletRegistrationForTesting(
        id: id,
        network: network,
        signer: WalletSigner.local,
        isDefault: true,
        masterFingerprint: secret.id,
        secretFingerprint: secret.id,
      ),
    );
    return Ok(id);
  }

  @override
  Future<Result<void, ParentCustodyFailure>> importMnemonic({
    required Fingerprint parent,
    required Secrets secrets,
    required ParentCustodyAdmissionPort admission,
    required BitcoinNetwork network,
    required ScriptType scriptType,
    String? label,
  }) async => throw UnimplementedError();

  @override
  Future<Result<void, WalletProvisioningFailure>> importDescriptor(
    WatchOnlyAccount account,
  ) async => throw UnimplementedError();

  @override
  Future<Result<void, WalletProvisioningFailure>> importXpub({
    required String xpub,
    required BitcoinNetwork network,
    required ScriptType scriptType,
    required String label,
  }) async => throw UnimplementedError();
}

void main() {
  test('an existing seed refuses the first-install choice', () async {
    FakeSecureStoragePlatform().install();
    final secrets = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => '/tmp/opencode',
    );
    expect(
      await secrets.import(
        words: [...List.filled(11, 'abandon'), 'about'],
        language: Language.english,
      ),
      isA<Ok<Secret, SecretFailure>>(),
    );
    final preferences = _Preferences();
    final electrum = _Electrum();
    final result = await StartupNetwork.apply(
      preferences: preferences,
      electrum: electrum,
      network: NetworkEnv.testnet,
      superuserUnlocked: true,
      developerConsent: true,
      isProtected: () async => const Ok(false),
      hasWallets: () async => const Ok(false),
      listSecrets: secrets.list,
    );
    expect(result, isA<Err<void, SettingsFailure>>());
    verifyZeroInteractions(preferences);
    verifyZeroInteractions(electrum);
  });

  for (final target in [
    NetworkEnv.testnet,
    if (RegtestHostProfile.isConfigured) NetworkEnv.regtest,
  ]) {
    for (final recover in [false, true]) {
      test(
        '$target selection precedes ${recover ? "recovery" : "creation"}',
        () async {
          final storage = FakeSecureStoragePlatform()..install();
          SharedPreferences.setMockInitialValues({
            'wizard_pending_version': 1,
            'wizard_pending_network': target.name,
          });
          final wizard = WizardFeature.mount();
          final secrets = Secrets(
            authority: unlockedSessionAuthority(),
            scratchDirectory: () async => '/tmp/opencode',
          );
          final inventory = _Inventory();
          final accounts = _Accounts(inventory);
          final preferences = _Preferences();
          final electrum = _Electrum();
          var environment = Environment.mainnet;
          when(() => preferences.setIsSuperuser(true))
              .thenAnswer((_) async => const Ok(null));
          when(() => preferences.setIsDevMode(true))
              .thenAnswer((_) async => const Ok(null));
          when(preferences.fetch).thenAnswer(
            (_) async => Ok(
              SettingsEntity(
                environment: environment,
                bitcoinUnit: BitcoinUnit.sats,
                currencyCode: 'USD',
                isSuperuser: true,
                isDevModeEnabled: true,
              ),
            ),
          );
          final selected = Environment.values.byName(target.name);
          when(() => electrum.prepareForegroundStorage(NetworkEnv.regtest))
              .thenAnswer((_) async => const Ok(null));
          when(() => preferences.setEnvironment(selected))
              .thenAnswer((_) async {
                environment = selected;
                return const Ok(null);
              });
          when(preferences.readActiveEnvironment)
              .thenAnswer((_) async => Ok(environment));
          // The fake account port receives real public domain objects.
          final provisioning = DefaultWalletProvisioning(
            secrets: secrets,
            inventory: inventory,
            environment: preferences,
            accounts: accounts,
          );
          final staged = await wizard.readPendingNetwork();
          expect(staged, isA<Ok<Environment?, WizardFailure>>());
          final selectedNetwork =
              (staged as Ok<Environment?, WizardFailure>).value;
          expect(selectedNetwork?.networkEnv, target);
          expect(
            await StartupNetwork.apply(
              preferences: preferences,
              electrum: electrum,
              network: target,
              superuserUnlocked: true,
              developerConsent: true,
              isProtected: () async => const Ok(false),
              hasWallets: () async => const Ok(false),
              listSecrets: secrets.list,
            ),
            isA<Ok<void, SettingsFailure>>(),
          );
          expect(
            await wizard.clearPendingNetwork(),
            isA<Ok<void, WizardFailure>>(),
          );
          final after = await wizard.readPendingNetwork();
          expect((after as Ok<Environment?, WizardFailure>).value, isNull);
          final result = recover
              ? await provisioning.execute(
                  mnemonicWords: [...List.filled(11, 'abandon'), 'about'],
                  language: Language.english,
                )
              : await provisioning.execute();
          expect(
            result,
            isA<Ok<List<WalletRegistration>, DefaultWalletFailure>>(),
          );
          expect(accounts.created, [
            BitcoinNetwork.values.byName(target.name),
            LiquidNetwork.values.byName(target.name),
          ]);
          expect(storage.entries, isNotEmpty);
        },
      );
    }
  }
}
