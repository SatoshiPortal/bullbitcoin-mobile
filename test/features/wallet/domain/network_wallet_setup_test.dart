import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_secret_references_repository.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_network_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/load_network_wallet_setup_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _Settings extends Mock implements SettingsRepository {}

class _References extends Mock implements WalletSecretReferencesRepository {}

class _CreateDefaults extends Mock implements CreateDefaultWalletsUsecase {}

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

  test(
    'empty mainnet keeps onboarding without enumerating references',
    () async {
      when(() => settings.fetch()).thenAnswer(
        (_) async => regtest.copyWith(environment: Environment.mainnet),
      );
      final result = await LoadNetworkWalletSetupUsecase(
        settings,
        references,
      ).execute();
      expect(
        (result as Ok<NetworkWalletSetup, WalletFailure>).value.network,
        NetworkEnv.mainnet,
      );
      verifyNever(() => references.list());
    },
  );

  test(
    'regtest offers catalog references and refuses developer mode off',
    () async {
      final usecase = LoadNetworkWalletSetupUsecase(settings, references);
      final result = await usecase.execute();
      expect((result as Ok<NetworkWalletSetup, WalletFailure>).value.reusable, [
        secret.id,
      ]);
      when(
        () => settings.fetch(),
      ).thenAnswer((_) async => regtest.copyWith(isDevModeEnabled: false));
      expect(
        await usecase.execute(),
        isA<Err<NetworkWalletSetup, WalletFailure>>(),
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
