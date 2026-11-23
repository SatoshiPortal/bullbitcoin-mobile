import 'package:bb_mobile/features/wallet/domain/network_wallet_setup_failure.dart';
import 'package:bb_mobile/features/wallet/domain/default_wallet_failure.dart';
import 'package:preferences/preferences.dart';
import 'package:secrets/storage.dart' show WalletInventory;
import 'package:bb_mobile/features/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_network_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/load_network_wallet_setup_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _Settings extends Mock implements Preferences {}

class _References extends Mock implements WalletInventory {}

class _CreateDefaults extends Mock implements CreateDefaultWalletsUsecase {}



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
    when(() => references.referencedFingerprints()).thenAnswer((_) async => Ok([secret.id]));
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
        when(references.referencedFingerprints).thenAnswer(
          (_) async => Ok([Fingerprint('deadbeef'), secret.id]),
        );
        final result = await LoadNetworkWalletSetupUsecase(
          settings,
          references,
          secrets,
        ).execute();
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
    final result = await LoadNetworkWalletSetupUsecase(
      settings,
      references,
      secrets,
    ).execute();
    expect(result, isA<Err<NetworkWalletSetup, NetworkWalletSetupFailure>>());
    expect(
      (result as Err).failure,
      isA<NetworkWalletSetupUnavailableFailure>(),
    );
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
    final result = await LoadNetworkWalletSetupUsecase(
      settings,
      references,
      secrets,
    ).execute();
    expect((result as Ok).value.reusable, [
      secret.id,
      french.id,
      passphrase.id,
    ]);
    final resultReuse = await CreateNetworkWalletUsecase(
      settings,
      references,
      secrets,
      create,
    ).execute(network: NetworkEnv.regtest, reuse: passphrase.id);
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
      final result = await LoadNetworkWalletSetupUsecase(
        settings,
        references,
        secrets,
      ).execute();
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
      final usecase = LoadNetworkWalletSetupUsecase(
        settings,
        references,
        secrets,
      );
      final result = await usecase.execute();
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
        await usecase.execute(),
        isA<Err<NetworkWalletSetup, NetworkWalletSetupFailure>>(),
      );
    },
  );

  test(
    'reuse passes the existing handle and retains custody after failure',
    () async {
      final before = Map<String, String>.of(storage.entries);
      final usecase = CreateNetworkWalletUsecase(
        settings,
        references,
        secrets,
        create,
      );
      expect(
        await usecase.execute(network: NetworkEnv.regtest, reuse: secret.id),
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
        await usecase.execute(network: NetworkEnv.regtest, reuse: secret.id),
        isA<Err>(),
      );
      expect(storage.entries, before);
    },
  );

  test(
    'generation delegates without reading a secret or enumerating custody',
    () async {
      final reads = storage.reads;
      final usecase = CreateNetworkWalletUsecase(
        settings,
        references,
        secrets,
        create,
      );
      expect(await usecase.execute(network: NetworkEnv.regtest), isA<Ok>());
      verify(
        () => create.execute(secret: null, expectedNetwork: NetworkEnv.regtest),
      ).called(1);
      verifyNever(() => references.referencedFingerprints());
      expect(storage.reads, reads);
    },
  );

  test('stale network selection is refused before provision', () async {
    final usecase = CreateNetworkWalletUsecase(
      settings,
      references,
      secrets,
      create,
    );
    expect(
      await usecase.execute(network: NetworkEnv.testnet, reuse: secret.id),
      isA<Err>(),
    );
    verifyNever(
      () => create.execute(
        secret: any(named: 'secret'),
        expectedNetwork: NetworkEnv.regtest,
      ),
    );
  });
}
