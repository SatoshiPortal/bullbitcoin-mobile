import 'package:preferences/preferences.dart';
import 'package:provisioning/provisioning.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _Settings extends Mock implements Preferences {}

class _References extends Mock implements WalletInventory {}

class _CreateDefaults extends Mock implements DefaultWalletProvisioning {}

void main() {
  late _Settings settings;
  late _References references;
  late _CreateDefaults create;
  late FakeSecureStoragePlatform storage;
  late Secrets secrets;
  late Secret secret;
  const regtest = (
    environment: Environment.regtest,

    isSuperuser: true,
    isDevModeEnabled: true,
  );
  final words = [...List.filled(11, 'abandon'), 'about'];

  NetworkWalletProvisioning provisioning() => NetworkWalletProvisioning(
    settings: settings,
    inventory: references,
    defaults: create,
    secrets: secrets,
  );

  setUp(() async {
    storage = FakeSecureStoragePlatform()..install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
    secret = (await secrets.import(
      words: words,
      language: bip39.Language.english,
    ) as Ok<Secret, SecretFailure>).value;
    registerFallbackValue(secret);
    settings = _Settings();
    references = _References();
    create = _CreateDefaults();
    when(() => settings.readDeveloperEnvironment())
        .thenAnswer((_) async => Ok(regtest));
    when(() => references.referencedFingerprints())
        .thenAnswer((_) async => Ok([secret.id]));
    when(
      () => create.execute(
        secret: any(named: 'secret'),
        expectedNetwork: NetworkEnv.regtest,
      ),
    ).thenAnswer((_) async => const Ok([]));
  });

  for (final environment in [Environment.regtest, Environment.testnet]) {
    test(
      'remote descriptor keeps setup available on ${environment.name}',
      () async {
        when(settings.readDeveloperEnvironment).thenAnswer(
          (_) async => Ok((
            environment: environment,
            isSuperuser: regtest.isSuperuser,
            isDevModeEnabled: regtest.isDevModeEnabled,
          )),
        );
        when(references.referencedFingerprints)
            .thenAnswer((_) async => Ok([Fingerprint('deadbeef'), secret.id]));
        final result = await provisioning().load();
        expect(
          result,
          isA<Ok<NetworkWalletSetup, NetworkWalletSetupFailure>>(),
        );
        final setup =
            (result as Ok<NetworkWalletSetup, NetworkWalletSetupFailure>).value;
        expect(setup.network, environment.networkEnv);
        expect(setup.reusable, [secret.id]);
      },
    );
  }

  test('secret storage failure keeps setup unavailable', () async {
    storage.locked = true;
    final result = await provisioning().load();
    expect(result, isA<Err<NetworkWalletSetup, NetworkWalletSetupFailure>>());
    expect(
      (result as Err).failure,
      isA<NetworkWalletSetupUnavailableFailure>(),
    );
  });

  test('catalog failure is reported as storage failure', () async {
    when(() => references.referencedFingerprints())
        .thenAnswer((_) async => const Err(KeystoreLockedFailure()));

    final result = await provisioning().load();

    expect((result as Err).failure, isA<NetworkWalletSetupStorageFailure>());
  });

  test('setup offers French and protected mnemonic seeds for reuse', () async {
    final frenchWords = bip39.Mnemonic(
      List.filled(16, 0),
      bip39.Language.french,
    ).sentence.split(' ');
    final french = (await secrets.import(
      words: frenchWords,
      language: bip39.Language.french,
    ) as Ok<Secret, SecretFailure>).value;
    final passphrase = (await secrets.import(
      words: words,
      passphrase: 'TREZOR',
      language: bip39.Language.english,
    ) as Ok<Secret, SecretFailure>).value;
    when(() => references.referencedFingerprints())
        .thenAnswer((_) async => Ok([secret.id, french.id, passphrase.id]));
    final result = await provisioning().load();
    expect((result as Ok).value.reusable, [
      secret.id,
      french.id,
      passphrase.id,
    ]);
    final resultReuse = await provisioning().create(
      network: NetworkEnv.regtest,
      reuse: passphrase.id,
    );
    expect(resultReuse, isA<Ok>());
    final forwarded =
        verify(
              () => create.execute(
                secret: captureAny(named: 'secret'),
                expectedNetwork: NetworkEnv.regtest,
              ),
            ).captured.single
            as Secret;
    expect(forwarded.id, passphrase.id);
    expect(forwarded.info.hasPassphrase, isTrue);
    expect((await forwarded.verify.passphrase('TREZOR') as Ok).value, isTrue);
  });

  test(
    'empty mainnet keeps onboarding without enumerating references',
    () async {
      when(() => settings.readDeveloperEnvironment()).thenAnswer(
        (_) async => Ok((
          environment: Environment.mainnet,
          isSuperuser: regtest.isSuperuser,
          isDevModeEnabled: regtest.isDevModeEnabled,
        )),
      );
      final result = await provisioning().load();
      expect(
        (result as Ok<NetworkWalletSetup, NetworkWalletSetupFailure>)
            .value
            .network,
        NetworkEnv.mainnet,
      );
      verifyNever(() => references.referencedFingerprints());
    },
  );

  test(
    'regtest offers catalog references and refuses developer mode off',
    () async {
      final usecase = provisioning();
      final result = await usecase.load();
      expect(
        (result as Ok<NetworkWalletSetup, NetworkWalletSetupFailure>)
            .value
            .reusable,
        [secret.id],
      );
      when(() => settings.readDeveloperEnvironment()).thenAnswer(
        (_) async => Ok((
          environment: regtest.environment,
          isSuperuser: regtest.isSuperuser,
          isDevModeEnabled: false,
        )),
      );
      expect(
        await usecase.load(),
        isA<Err<NetworkWalletSetup, NetworkWalletSetupFailure>>(),
      );
    },
  );

  test(
    'reuse passes the existing handle and retains custody after failure',
    () async {
      final before = Map<String, String>.of(storage.entries);
      final usecase = provisioning();
      expect(
        await usecase.create(network: NetworkEnv.regtest, reuse: secret.id),
        isA<Ok>(),
      );
      final supplied =
          verify(
                () => create.execute(
                  secret: captureAny(named: 'secret'),
                  expectedNetwork: NetworkEnv.regtest,
                ),
              ).captured.single
              as Secret;
      expect(supplied.id, secret.id);
      when(
        () => create.execute(
          secret: any(named: 'secret'),
          expectedNetwork: NetworkEnv.regtest,
        ),
      ).thenAnswer((_) async => const Err(DefaultWalletCreationFailure()));
      expect(
        await usecase.create(network: NetworkEnv.regtest, reuse: secret.id),
        isA<Err>(),
      );
      expect(storage.entries, before);
    },
  );

  test(
    'generation delegates without reading a secret or enumerating custody',
    () async {
      final reads = storage.reads;
      final usecase = provisioning();
      expect(await usecase.create(network: NetworkEnv.regtest), isA<Ok>());
      verify(
        () => create.execute(secret: null, expectedNetwork: NetworkEnv.regtest),
      ).called(1);
      verifyNever(() => references.referencedFingerprints());
      expect(storage.reads, reads);
    },
  );

  test('stale network selection is refused before provision', () async {
    final usecase = provisioning();
    expect(
      await usecase.create(network: NetworkEnv.testnet, reuse: secret.id),
      isA<Err>(),
    );
    verifyNever(
      () => create.execute(
        secret: any(named: 'secret'),
        expectedNetwork: NetworkEnv.regtest,
      ),
    );
  });

  test('backup required from default provisioning remains distinct', () async {
    when(
      () => create.execute(
        secret: any(named: 'secret'),
        expectedNetwork: NetworkEnv.regtest,
      ),
    ).thenAnswer((_) async => const Err(DefaultWalletBackupRequiredFailure()));

    final result = await provisioning().create(network: NetworkEnv.regtest);

    expect(
      (result as Err).failure,
      isA<NetworkWalletSetupBackupRequiredFailure>(),
    );
  });

  test(
    'stale catalog reference is refused before fetching or provisioning',
    () async {
      when(() => references.referencedFingerprints())
          .thenAnswer((_) async => const Ok([]));
      final reads = storage.reads;

      final result = await provisioning().create(
        network: NetworkEnv.regtest,
        reuse: secret.id,
      );

      expect(
        (result as Err).failure,
        isA<NetworkWalletSetupReferenceNotFoundFailure>(),
      );
      expect(storage.reads, reads);
      verifyNever(
        () => create.execute(
          secret: any(named: 'secret'),
          expectedNetwork: NetworkEnv.regtest,
        ),
      );
    },
  );
}
