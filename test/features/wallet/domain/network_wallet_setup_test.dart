import 'package:bb_mobile/features/wallet/data/catalog_wallet_secret_references_repository.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart'
    show Signer;
import 'package:bb_mobile/features/wallet/domain/network_wallet_setup_failure.dart';
import 'package:bb_mobile/features/wallet/domain/default_wallet_secret_policy.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_secret_references_repository.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_network_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/load_network_wallet_setup_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _Settings extends Mock implements SettingsRepository {}

class _References extends Mock implements WalletSecretReferencesRepository {}

class _CreateDefaults extends Mock implements CreateDefaultWalletsUsecase {}

class _Metadata extends Mock implements WalletMetadataDatasource {}

class _Row extends Mock implements WalletMetadataModel {}

void main() {
  late _Settings settings;
  late _References references;
  late _CreateDefaults create;
  late FakeSecureStoragePlatform storage;
  late Secrets secrets;
  late Secret secret;
  const regtest = SettingsEntity(
    environment: Environment.regtest,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'CAD',
    isSuperuser: true,
    isDevModeEnabled: true,
  );
  final words = [...List.filled(11, 'abandon'), 'about'];

  setUp(() async {
    storage = FakeSecureStoragePlatform()..install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
    secret =
        (await secrets.import(words: words) as Ok<Secret, SecretFailure>).value;
    registerFallbackValue(secret);
    settings = _Settings();
    references = _References();
    create = _CreateDefaults();
    when(() => settings.fetch()).thenAnswer((_) async => regtest);
    when(() => references.list()).thenAnswer((_) async => Ok([secret.id]));
    when(
      () => create.execute(
        secret: any(named: 'secret'),
        expectedNetwork: NetworkEnv.regtest,
      ),
    ).thenAnswer((_) async => []);
  });

  for (final environment in [Environment.regtest, Environment.testnet]) {
    test(
      'remote descriptor keeps setup available on ${environment.name}',
      () async {
        when(
          settings.fetch,
        ).thenAnswer((_) async => regtest.copyWith(environment: environment));
        final localRow = _Row();
        when(() => localRow.masterFingerprint).thenReturn(secret.id.hex);
        when(() => localRow.signer).thenReturn(Signer.local);
        // A public descriptor origin has no local secret by design.
        final remoteRow = _Row();
        when(() => remoteRow.masterFingerprint).thenReturn('deadbeef');
        when(() => remoteRow.signer).thenReturn(Signer.remote);
        final metadata = _Metadata();
        when(metadata.fetchAll).thenAnswer((_) async => [remoteRow, localRow]);
        final catalog = CatalogWalletSecretReferencesRepository(metadata);
        final allReferences = await catalog.list();
        expect((allReferences as Ok).value, [
          Fingerprint.tryParse('deadbeef'),
          secret.id,
        ]);
        final result = await LoadNetworkWalletSetupUsecase(
          settings,
          catalog,
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

  test(
    'setup offers French seeds for reuse and excludes passphrase seeds',
    () async {
      final frenchWords = bip39.Mnemonic(
        List.filled(16, 0),
        bip39.Language.french,
      ).sentence.split(' ');
      final french =
          (await secrets.import(
                    words: frenchWords,
                    language: bip39.Language.french,
                  )
                  as Ok<Secret, SecretFailure>)
              .value;
      final passphrase =
          (await secrets.import(words: words, passphrase: 'TREZOR')
                  as Ok<Secret, SecretFailure>)
              .value;
      when(
        () => references.list(),
      ).thenAnswer((_) async => Ok([secret.id, french.id, passphrase.id]));
      final result = await LoadNetworkWalletSetupUsecase(
        settings,
        references,
        secrets,
      ).execute();
      expect((result as Ok).value.reusable, [secret.id, french.id]);
      final refusal = await CreateNetworkWalletUsecase(
        settings,
        references,
        secrets,
        create,
      ).execute(network: NetworkEnv.regtest, reuse: passphrase.id);
      expect(refusal, isA<Err>());
      expect(
        (refusal as Err).failure,
        isA<NetworkWalletSetupSecretFailure>().having(
          (f) => f.reason,
          'reason',
          DefaultWalletSecretRefusal.passphrase,
        ),
      );
      verifyNever(
        () => create.execute(
          secret: any(named: 'secret'),
          expectedNetwork: NetworkEnv.regtest,
        ),
      );
    },
  );

  test(
    'empty mainnet keeps onboarding without enumerating references',
    () async {
      when(() => settings.fetch()).thenAnswer(
        (_) async => regtest.copyWith(environment: Environment.mainnet),
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
      verifyNever(() => references.list());
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
      when(
        () => settings.fetch(),
      ).thenAnswer((_) async => regtest.copyWith(isDevModeEnabled: false));
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
      ).thenThrow(CreateDefaultWalletsException('unavailable'));
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
      verifyNever(() => references.list());
      expect(storage.reads, reads);
    },
  );

  test(
    'stale selection and passphrase secrets are refused before provision',
    () async {
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
      final passphrase =
          (await secrets.import(words: words, passphrase: 'TREZOR')
                  as Ok<Secret, SecretFailure>)
              .value;
      when(
        () => references.list(),
      ).thenAnswer((_) async => Ok([passphrase.id]));
      expect(
        await usecase.execute(
          network: NetworkEnv.regtest,
          reuse: passphrase.id,
        ),
        isA<Err>(),
      );
      verifyNever(
        () => create.execute(
          secret: any(named: 'secret'),
          expectedNetwork: NetworkEnv.regtest,
        ),
      );
    },
  );
}
