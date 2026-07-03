import 'dart:typed_data';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/apply_wallet_behavior_defaults_usecase.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/bullnym/bullnym_locator.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/deterministic_wallets/public/deterministic_wallets_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/lightning_address/data/default_wallet_xprv_adapter.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_default_wallet_xprv_port.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_wallet_owned_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/prepare_lightning_address_wallet_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/register_lightning_address_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/register_wallet_owned_lightning_address_usecase.dart';
import 'package:bb_mobile/features/lightning_address/lightning_address_locator.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/nostr_identity/nostr_identity_locator.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:get_it/get_it.dart';
import 'package:test/test.dart';

void main() {
  group('RegisterWalletOwnedLightningAddressUsecase', () {
    late _FakeDefaultWalletXprvPort defaultWalletXprv;
    late _FakePrepareLightningAddressWalletUsecase prepareWallet;
    late _FakeRegisterLightningAddressUsecase register;
    late RegisterWalletOwnedLightningAddressUsecase usecase;

    setUp(() {
      defaultWalletXprv = _FakeDefaultWalletXprvPort();
      prepareWallet = _FakePrepareLightningAddressWalletUsecase();
      register = _FakeRegisterLightningAddressUsecase();
      usecase = RegisterWalletOwnedLightningAddressUsecase(
        defaultWalletXprv: defaultWalletXprv,
        prepareWallet: prepareWallet,
        register: register,
      );
    });

    test(
      'derives xprv, prepares wallet, and registers with descriptor',
      () async {
        final result = await usecase.execute(nym: 'alice');

        expect(defaultWalletXprv.deriveCalls, 1);
        expect(prepareWallet.executeCalls, 1);
        expect(register.commands.single.xprvBase58, 'xprv');
        expect(register.commands.single.nym, 'alice');
        expect(register.commands.single.ctDescriptor, 'ct-desc');
        expect(result.registration.nym, 'alice');
        expect(result.registration.lightningAddress, 'alice@example.invalid');
        expect(result.walletId, 'la-wallet');
        expect(result.walletCreated, true);
      },
    );

    test(
      'rejects blank nym before secret, wallet, or network side effects',
      () {
        expect(
          () => usecase.execute(nym: '  '),
          throwsA(
            isA<LightningAddressException>().having(
              (e) => e.kind,
              'kind',
              LightningAddressErrorKind.invalidNym,
            ),
          ),
        );
        expect(defaultWalletXprv.deriveCalls, 0);
        expect(prepareWallet.executeCalls, 0);
        expect(register.commands, isEmpty);
      },
    );

    test(
      'maps default-wallet xprv failures before wallet preparation',
      () async {
        defaultWalletXprv.error = StateError('no default wallet');

        await expectLater(
          usecase.execute(nym: 'alice'),
          throwsA(
            isA<WalletOwnedLightningAddressRegistrationException>()
                .having(
                  (e) => e.phase,
                  'phase',
                  WalletOwnedLightningAddressRegistrationFailurePhase
                      .localPreparation,
                )
                .having(
                  (e) => e.cause.kind,
                  'kind',
                  LightningAddressErrorKind.localPreparationFailed,
                )
                .having((e) => e.cause.retryable, 'retryable', true),
          ),
        );
        expect(prepareWallet.executeCalls, 0);
        expect(register.commands, isEmpty);
      },
    );

    test('does not register when wallet preparation fails', () async {
      prepareWallet.error = LightningAddressException.localPreparationFailed(
        code: 'ManifestFailed',
        retryable: true,
      );

      await expectLater(
        usecase.execute(nym: 'alice'),
        throwsA(
          isA<WalletOwnedLightningAddressRegistrationException>()
              .having(
                (e) => e.phase,
                'phase',
                WalletOwnedLightningAddressRegistrationFailurePhase
                    .localPreparation,
              )
              .having(
                (e) => e.cause.kind,
                'kind',
                LightningAddressErrorKind.localPreparationFailed,
              ),
        ),
      );
      expect(register.commands, isEmpty);
    });

    test('keeps prepared wallet boundary when registration fails', () async {
      register.error = const LightningAddressTimeoutException(
        code: 'Timeout',
        retryable: true,
      );

      await expectLater(
        usecase.execute(nym: 'alice'),
        throwsA(
          isA<WalletOwnedLightningAddressRegistrationException>()
              .having(
                (e) => e.phase,
                'phase',
                WalletOwnedLightningAddressRegistrationFailurePhase
                    .registrationSubmission,
              )
              .having((e) => e.walletId, 'walletId', 'la-wallet')
              .having((e) => e.walletCreated, 'walletCreated', true)
              .having(
                (e) => e.descriptorMayHaveBeenSubmitted,
                'descriptorMayHaveBeenSubmitted',
                true,
              )
              .having(
                (e) => e.submissionMayBeUncertain,
                'submissionMayBeUncertain',
                true,
              )
              .having(
                (e) => e.cause.kind,
                'kind',
                LightningAddressErrorKind.timeout,
              ),
        ),
      );
      expect(prepareWallet.executeCalls, 1);
      expect(register.commands.single.ctDescriptor, 'ct-desc');
    });

    test('does not mark signing failures as submitted to server', () async {
      register.error = const LightningAddressSigningFailedException(
        code: 'SigningFailed',
        retryable: false,
      );

      await expectLater(
        usecase.execute(nym: 'alice'),
        throwsA(
          isA<WalletOwnedLightningAddressRegistrationException>()
              .having(
                (e) => e.descriptorMayHaveBeenSubmitted,
                'descriptorMayHaveBeenSubmitted',
                false,
              )
              .having(
                (e) => e.submissionMayBeUncertain,
                'submissionMayBeUncertain',
                false,
              ),
        ),
      );
    });

    test(
      'keeps retryable server rejection distinct from uncertainty',
      () async {
        register.error = const LightningAddressServerRejectedRequestException(
          code: 'TemporarilyUnavailable',
          retryable: true,
        );

        await expectLater(
          usecase.execute(nym: 'alice'),
          throwsA(
            isA<WalletOwnedLightningAddressRegistrationException>()
                .having(
                  (e) => e.phase,
                  'phase',
                  WalletOwnedLightningAddressRegistrationFailurePhase
                      .registrationSubmission,
                )
                .having(
                  (e) => e.submissionMayBeUncertain,
                  'submissionMayBeUncertain',
                  false,
                )
                .having((e) => e.cause.retryable, 'retryable', true),
          ),
        );
        expect(prepareWallet.executeCalls, 1);
        expect(register.commands.single.ctDescriptor, 'ct-desc');
      },
    );

    test('reports reused wallet metadata for idempotent retry', () async {
      prepareWallet.prepared = _prepared(created: false);

      final result = await usecase.execute(nym: 'alice');

      expect(result.walletId, 'la-wallet');
      expect(result.walletCreated, false);
    });
  });

  group('LookupWalletOwnedLightningAddressRegistrationUsecase', () {
    late _FakeDefaultWalletXprvPort defaultWalletXprv;
    late _FakeLookupLightningAddressRegistrationUsecase lookupRegistration;
    late _FakeNostrIdentityFacade nostrIdentity;
    late LookupWalletOwnedLightningAddressRegistrationUsecase usecase;

    setUp(() {
      defaultWalletXprv = _FakeDefaultWalletXprvPort();
      lookupRegistration = _FakeLookupLightningAddressRegistrationUsecase();
      nostrIdentity = _FakeNostrIdentityFacade();
      usecase = LookupWalletOwnedLightningAddressRegistrationUsecase(
        defaultWalletXprv: defaultWalletXprv,
        lookupRegistration: lookupRegistration,
        nostrIdentity: nostrIdentity,
      );
    });

    test('derives xprv internally and returns Bullnym status', () async {
      final result = await usecase.execute();

      expect(defaultWalletXprv.deriveCalls, 1);
      expect(nostrIdentity.xprvs.single, 'xprv');
      expect(lookupRegistration.executeCalls, 1);
      expect(lookupRegistration.npubHex, 'npubhex');
      expect(result.nym, 'alice');
      expect(result.active, true);
    });

    test('maps default-wallet xprv failures before lookup', () async {
      defaultWalletXprv.error = StateError('no default wallet');

      await expectLater(
        usecase.execute(),
        throwsA(
          isA<LightningAddressException>().having(
            (e) => e.kind,
            'kind',
            LightningAddressErrorKind.localPreparationFailed,
          ),
        ),
      );
      expect(lookupRegistration.executeCalls, 0);
    });

    test('maps Nostr public-key derivation failures before lookup', () async {
      nostrIdentity.error = StateError('bad xprv');

      await expectLater(
        usecase.execute(),
        throwsA(
          isA<LightningAddressException>()
              .having(
                (e) => e.kind,
                'kind',
                LightningAddressErrorKind.localPreparationFailed,
              )
              .having((e) => e.retryable, 'retryable', false),
        ),
      );
      expect(lookupRegistration.executeCalls, 0);
    });
  });

  test('LightningAddressFacade delegates wallet-owned registration', () async {
    final walletOwned = _FakeRegisterWalletOwnedLightningAddressUsecase();
    final lookupWalletOwned =
        _FakeLookupWalletOwnedLightningAddressRegistrationUsecase();
    final facade = LightningAddressFacade(
      prepareWallet: _FakePrepareLightningAddressWalletUsecase().execute,
      lookupRegistration: ({required npubHex}) =>
          _FakeLookupLightningAddressRegistrationUsecase().execute(
            npubHex: npubHex,
          ),
      registerWalletOwned: ({required nym}) => walletOwned.execute(nym: nym),
      lookupWalletOwnedRegistration: lookupWalletOwned.execute,
    );

    final result = await facade.registerWalletOwned(nym: 'alice');

    expect(walletOwned.nyms.single, 'alice');
    expect(result.registration.lightningAddress, 'alice@example.invalid');
  });

  test('LightningAddressFacade delegates wallet-owned lookup', () async {
    final lookupWalletOwned =
        _FakeLookupWalletOwnedLightningAddressRegistrationUsecase();
    final facade = LightningAddressFacade(
      prepareWallet: _FakePrepareLightningAddressWalletUsecase().execute,
      lookupRegistration: ({required npubHex}) =>
          _FakeLookupLightningAddressRegistrationUsecase().execute(
            npubHex: npubHex,
          ),
      registerWalletOwned: ({required nym}) =>
          _FakeRegisterWalletOwnedLightningAddressUsecase().execute(nym: nym),
      lookupWalletOwnedRegistration: lookupWalletOwned.execute,
    );

    final result = await facade.lookupWalletOwnedRegistration();

    expect(lookupWalletOwned.executeCalls, 1);
    expect(result.nym, 'alice');
    expect(result.active, true);
  });

  test(
    'DefaultWalletXprvAdapter derives from the active-environment default wallet',
    () async {
      final seed = _zeroMnemonicSeed();
      final walletRepository = _FakeWalletRepository([
        _wallet(
          'default-testnet',
          network: Network.bitcoinTestnet,
          masterFingerprint: 'test-fp',
        ),
        _wallet(
          'default-mainnet',
          network: Network.bitcoinMainnet,
          masterFingerprint: 'main-fp',
        ),
      ]);
      final seedRepository = _FakeSeedRepository(seed);
      final adapter = DefaultWalletXprvAdapter(
        getSettings: _FakeGetSettingsUsecase(Environment.mainnet),
        walletRepository: walletRepository,
        seedRepository: seedRepository,
      );

      final xprv = await adapter.deriveDefaultWalletXprv();

      expect(walletRepository.onlyDefaults, true);
      expect(walletRepository.onlyBitcoin, true);
      expect(walletRepository.environment, Environment.mainnet);
      expect(seedRepository.fingerprints.single, 'main-fp');
      expect(xprv, startsWith('xprv'));
    },
  );

  test('feature locators resolve the headless Lightning Address facade', () {
    final getIt = GetIt.asNewInstance();
    getIt.registerFactory<WalletRepository>(
      () => _FakeWalletRepository([
        _wallet('default-bitcoin', network: Network.bitcoinMainnet),
      ]),
    );
    getIt.registerFactory<SeedRepository>(
      () => _FakeSeedRepository(_zeroMnemonicSeed()),
    );
    getIt.registerFactory<GetSettingsUsecase>(() => _FakeGetSettingsUsecase());
    getIt.registerFactory<DeterministicWalletsFacade>(
      () => _FakeDeterministicWalletsFacade(),
    );
    getIt.registerFactory<KeychainManifestFacade>(
      () => _FakeKeychainManifestFacade(),
    );
    getIt.registerLazySingleton<Bip85RegistryFacade>(
      () => const Bip85RegistryFacade(),
    );
    getIt.registerFactory<ApplyWalletBehaviorDefaultsUsecase>(
      () => _FakeApplyWalletBehaviorDefaultsUsecase(),
    );

    BullnymLocator.setup(getIt);
    NostrIdentityLocator.setup(getIt);
    LightningAddressLocator.setup(getIt);

    expect(getIt<BullnymFacade>(), isA<BullnymFacade>());
    expect(getIt<NostrIdentityFacade>(), isA<NostrIdentityFacade>());
    expect(getIt<LightningAddressFacade>(), isA<LightningAddressFacade>());
  });
}

class _FakeDefaultWalletXprvPort
    implements LightningAddressDefaultWalletXprvPort {
  int deriveCalls = 0;
  Object? error;

  @override
  Future<String> deriveDefaultWalletXprv() async {
    deriveCalls += 1;
    final error = this.error;
    if (error != null) throw error;
    return 'xprv';
  }
}

class _FakePrepareLightningAddressWalletUsecase
    implements PrepareLightningAddressWalletUsecase {
  int executeCalls = 0;
  PreparedLightningAddressWallet prepared = _prepared();
  LightningAddressException? error;

  @override
  Future<PreparedLightningAddressWallet> execute() async {
    executeCalls += 1;
    final error = this.error;
    if (error != null) throw error;
    return prepared;
  }
}

class _FakeRegisterLightningAddressUsecase
    implements RegisterLightningAddressUsecase {
  final commands = <({String xprvBase58, String nym, String ctDescriptor})>[];
  LightningAddressException? error;

  @override
  Future<LightningAddressRegistration> execute({
    required String xprvBase58,
    required String nym,
    required String ctDescriptor,
  }) async {
    commands.add((
      xprvBase58: xprvBase58,
      nym: nym,
      ctDescriptor: ctDescriptor,
    ));
    final error = this.error;
    if (error != null) throw error;
    return LightningAddressRegistration(
      nym: nym,
      lightningAddress: '$nym@example.invalid',
    );
  }
}

class _FakeRegisterWalletOwnedLightningAddressUsecase
    implements RegisterWalletOwnedLightningAddressUsecase {
  final nyms = <String>[];

  @override
  Future<WalletOwnedLightningAddressRegistration> execute({
    required String nym,
  }) async {
    nyms.add(nym);
    return WalletOwnedLightningAddressRegistration(
      registration: LightningAddressRegistration(
        nym: nym,
        lightningAddress: '$nym@example.invalid',
      ),
      walletId: 'la-wallet',
      walletCreated: true,
    );
  }
}

class _FakeLookupLightningAddressRegistrationUsecase
    implements LookupLightningAddressRegistrationUsecase {
  int executeCalls = 0;
  String? npubHex;

  @override
  Future<LightningAddressStatus> execute({required String npubHex}) async {
    executeCalls += 1;
    this.npubHex = npubHex;
    return const LightningAddressStatus(nym: 'alice', active: true);
  }
}

class _FakeNostrIdentityFacade implements NostrIdentityFacade {
  final xprvs = <String>[];
  Object? error;

  @override
  String deriveBullnymServerAuthPublicKeyFromXprv(String xprvBase58) {
    xprvs.add(xprvBase58);
    final error = this.error;
    if (error != null) throw error;
    return 'npubhex';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLookupWalletOwnedLightningAddressRegistrationUsecase
    implements LookupWalletOwnedLightningAddressRegistrationUsecase {
  int executeCalls = 0;

  @override
  Future<LightningAddressStatus> execute() async {
    executeCalls += 1;
    return const LightningAddressStatus(nym: 'alice', active: true);
  }
}

class _FakeWalletRepository implements WalletRepository {
  final List<Wallet> wallets;
  Environment? environment;
  bool? onlyDefaults;
  bool? onlyBitcoin;

  _FakeWalletRepository(this.wallets);

  @override
  Future<List<Wallet>> getWallets({
    Environment? environment,
    bool? onlyDefaults,
    bool? onlyBitcoin,
    bool? onlyLiquid,
    bool sync = false,
  }) async {
    this.environment = environment;
    this.onlyDefaults = onlyDefaults;
    this.onlyBitcoin = onlyBitcoin;
    return wallets.where((wallet) {
      if (environment == null) return true;
      return switch (environment) {
        Environment.mainnet => wallet.network == Network.bitcoinMainnet,
        Environment.testnet => wallet.network == Network.bitcoinTestnet,
      };
    }).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSeedRepository implements SeedRepository {
  final Seed seed;
  final fingerprints = <String>[];

  _FakeSeedRepository(this.seed);

  @override
  Future<Seed> get(String fingerprint) async {
    fingerprints.add(fingerprint);
    return seed;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGetSettingsUsecase implements GetSettingsUsecase {
  final Environment environment;

  _FakeGetSettingsUsecase([this.environment = Environment.mainnet]);

  @override
  Future<SettingsEntity> execute() async {
    return SettingsEntity(
      environment: environment,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'USD',
    );
  }
}

class _FakeDeterministicWalletsFacade implements DeterministicWalletsFacade {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeKeychainManifestFacade implements KeychainManifestFacade {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeApplyWalletBehaviorDefaultsUsecase
    implements ApplyWalletBehaviorDefaultsUsecase {
  @override
  Future<void> execute({
    required String walletId,
    bool? hideOnHome,
    bool? autoSweepEnabled,
  }) async {}
}

PreparedLightningAddressWallet _prepared({bool created = true}) {
  return PreparedLightningAddressWallet(
    walletId: 'la-wallet',
    ctDescriptor: 'ct-desc',
    created: created,
  );
}

Wallet _wallet(
  String id, {
  Network network = Network.liquidMainnet,
  String masterFingerprint = 'child-fp',
}) {
  return Wallet(
    origin: id,
    network: network,
    masterFingerprint: masterFingerprint,
    xpubFingerprint: masterFingerprint,
    scriptType: ScriptType.bip84,
    xpub: 'xpub',
    externalPublicDescriptor: 'ct-desc',
    internalPublicDescriptor: 'internal',
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: BigInt.zero,
  );
}

Seed _zeroMnemonicSeed() {
  final mnemonic = bip39.Mnemonic.fromSentence(
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
    bip39.Language.english,
  );
  return Seed.mnemonic(
    mnemonicWords: mnemonic.words,
    bytes: Uint8List.fromList(mnemonic.seed),
    masterFingerprint: 'parent-fp',
  );
}
