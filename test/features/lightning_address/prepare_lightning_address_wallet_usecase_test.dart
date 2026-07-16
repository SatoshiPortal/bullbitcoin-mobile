import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/apply_wallet_behavior_defaults_usecase.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/deterministic_wallets/public/deterministic_wallets_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/prepare_lightning_address_wallet_usecase.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeGetSettingsUsecase getSettings;
  late _FakeDeterministicWalletsFacade deterministicWallets;
  late _FakeKeychainManifestFacade keychainManifest;
  late _FakeApplyWalletBehaviorDefaultsUsecase applyWalletBehaviorDefaults;
  late PrepareLightningAddressWalletUsecase usecase;

  setUp(() {
    getSettings = _FakeGetSettingsUsecase();
    deterministicWallets = _FakeDeterministicWalletsFacade();
    keychainManifest = _FakeKeychainManifestFacade();
    applyWalletBehaviorDefaults = _FakeApplyWalletBehaviorDefaultsUsecase();
    usecase = PrepareLightningAddressWalletUsecase(
      getSettings: getSettings,
      deterministicWallets: deterministicWallets,
      keychainManifest: keychainManifest,
      applyWalletBehaviorDefaults: applyWalletBehaviorDefaults,
      bip85Registry: const Bip85RegistryFacade(),
    );
  });

  test(
    'prepares the Lightning Address Liquid wallet from reservation 101',
    () async {
      final result = await usecase.execute();

      expect(result.walletId, 'la-wallet');
      expect(result.created, true);
      expect(result.ctDescriptor, 'ct-desc');
      final request = deterministicWallets.prepareRequests.single;
      expect(request.bip85Index, 101);
      expect(request.bip85Alias, 'Lightning Address');
      expect(request.environment, Environment.mainnet);
      expect(request.walletSpecs, hasLength(1));
      expect(request.walletSpecs.single.id, 'lightning-address-liquid');
      expect(request.walletSpecs.single.network, Network.liquidMainnet);
      expect(request.walletSpecs.single.scriptType, ScriptType.bip84);
      expect(request.walletSpecs.single.label, 'Lightning Address Liquid');
      expect(request.walletSpecs.single.isDefault, false);
      expect(request.walletSpecs.single.sync, false);
    },
  );

  test('uses the testnet Liquid network in testnet environments', () async {
    getSettings.environment = Environment.testnet;

    await usecase.execute();

    expect(
      deterministicWallets.prepareRequests.single.walletSpecs.single.network,
      Network.liquidTestnet,
    );
  });

  test('records the prepared wallet in the keychain manifest', () async {
    await usecase.execute();

    final request = keychainManifest.recordRequests.single;
    expect(request.reservationId, 'lightning_address_wallet_seed');
    expect(request.parentFingerprint, 'parent-fp');
    expect(request.materializations, hasLength(1));
    final materialization = request.materializations.single;
    expect(materialization.walletId, 'la-wallet');
    expect(materialization.childSeedFingerprint, 'child-fp');
    expect(materialization.network, Network.liquidMainnet);
    expect(materialization.scriptType, ScriptType.bip84);
  });

  test('applies Lightning Address wallet behavior defaults', () async {
    await usecase.execute();

    final request = applyWalletBehaviorDefaults.requests.single;
    expect(request.walletId, 'la-wallet');
    expect(request.hideOnHome, true);
    expect(request.autoSweepEnabled, true);
  });

  test('reuses existing wallet materializations idempotently', () async {
    deterministicWallets.prepared = _prepared(created: false);

    final result = await usecase.execute();

    expect(result.created, false);
    expect(keychainManifest.recordRequests, hasLength(1));
    expect(deterministicWallets.rollbackRequests, isEmpty);
  });

  test('rolls back prepared wallets when manifest recording fails', () async {
    keychainManifest.recordError = KeychainManifestGenericException();

    await expectLater(
      usecase.execute(),
      throwsA(
        isA<LightningAddressException>()
            .having(
              (error) => error.kind,
              'kind',
              LightningAddressErrorKind.localPreparationFailed,
            )
            .having((error) => error.retryable, 'retryable', true),
      ),
    );

    expect(deterministicWallets.rollbackRequests, hasLength(1));
    expect(
      deterministicWallets.rollbackRequests.single.wallets.single.walletId,
      'la-wallet',
    );
  });

  test(
    'keeps prepared wallets when behavior defaults fail after manifest',
    () async {
      applyWalletBehaviorDefaults.error = StateError('metadata failed');

      await expectLater(
        usecase.execute(),
        throwsA(
          isA<LightningAddressException>().having(
            (error) => error.kind,
            'kind',
            LightningAddressErrorKind.localPreparationFailed,
          ),
        ),
      );

      expect(keychainManifest.recordRequests, hasLength(1));
      expect(deterministicWallets.rollbackRequests, isEmpty);
    },
  );

  test('reports durable manifest failures as non-retryable', () async {
    keychainManifest.recordError = KeychainManifestEntryConflictException(
      'wallet already has a manifest entry',
    );

    await expectLater(
      usecase.execute(),
      throwsA(
        isA<LightningAddressException>()
            .having(
              (error) => error.kind,
              'kind',
              LightningAddressErrorKind.localPreparationFailed,
            )
            .having((error) => error.retryable, 'retryable', false),
      ),
    );

    expect(deterministicWallets.rollbackRequests, hasLength(1));
  });

  test('reports generic deterministic wallet failures as retryable', () async {
    deterministicWallets.prepareFailure =
        const DeterministicWalletOperationFailure();

    await expectLater(
      usecase.execute(),
      throwsA(
        isA<LightningAddressException>()
            .having(
              (error) => error.kind,
              'kind',
              LightningAddressErrorKind.localPreparationFailed,
            )
            .having((error) => error.retryable, 'retryable', true),
      ),
    );

    expect(deterministicWallets.rollbackRequests, isEmpty);
  });

  test('reports deterministic wallet mismatches as non-retryable', () async {
    deterministicWallets.prepareFailure =
        const DeterministicWalletMismatchFailure();

    await expectLater(
      usecase.execute(),
      throwsA(
        isA<LightningAddressException>()
            .having(
              (error) => error.kind,
              'kind',
              LightningAddressErrorKind.unexpected,
            )
            .having((error) => error.retryable, 'retryable', false),
      ),
    );
  });
}

class _FakeGetSettingsUsecase implements GetSettingsUsecase {
  Environment environment = Environment.mainnet;

  @override
  Future<SettingsEntity> execute() async {
    return SettingsEntity(
      environment: environment,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'CAD',
    );
  }
}

class _FakeDeterministicWalletsFacade implements DeterministicWalletsFacade {
  final prepareRequests = <DeterministicWalletsRequest>[];
  final rollbackRequests = <PreparedDeterministicWallets>[];
  PreparedDeterministicWallets prepared = _prepared();
  DeterministicWalletFailure? prepareFailure;

  @override
  Future<Result<PreparedDeterministicWallets, DeterministicWalletFailure>>
  prepare(DeterministicWalletsRequest request) async {
    prepareRequests.add(request);
    final failure = prepareFailure;
    return failure == null ? Ok(prepared) : Err(failure);
  }

  @override
  Future<Result<void, DeterministicWalletFailure>> rollbackCreatedWallets(
    PreparedDeterministicWallets result,
  ) async {
    rollbackRequests.add(result);
    return const Ok(null);
  }
}

class _FakeKeychainManifestFacade implements KeychainManifestFacade {
  final recordRequests = <KeychainManifestReservedDerivationRequest>[];
  KeychainManifestException? recordError;

  @override
  Future<void> recordReservedDerivation(
    KeychainManifestReservedDerivationRequest request, {
    DateTime? now,
    bool scheduleBackup = true,
  }) async {
    final error = recordError;
    if (error != null) throw error;
    recordRequests.add(request);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ApplyWalletBehaviorRequest {
  final String walletId;
  final bool? hideOnHome;
  final bool? autoSweepEnabled;

  const _ApplyWalletBehaviorRequest({
    required this.walletId,
    required this.hideOnHome,
    required this.autoSweepEnabled,
  });
}

class _FakeApplyWalletBehaviorDefaultsUsecase
    implements ApplyWalletBehaviorDefaultsUsecase {
  final requests = <_ApplyWalletBehaviorRequest>[];
  Object? error;

  @override
  Future<void> execute({
    required String walletId,
    bool? hideOnHome,
    bool? autoSweepEnabled,
  }) async {
    final error = this.error;
    if (error != null) throw error;
    requests.add(
      _ApplyWalletBehaviorRequest(
        walletId: walletId,
        hideOnHome: hideOnHome,
        autoSweepEnabled: autoSweepEnabled,
      ),
    );
  }
}

PreparedDeterministicWallets _prepared({bool created = true}) {
  return PreparedDeterministicWallets(
    wallets: [
      PreparedDeterministicWallet(
        specId: 'lightning-address-liquid',
        walletId: 'la-wallet',
        network: Network.liquidMainnet,
        scriptType: ScriptType.bip84,
        label: 'Lightning Address Liquid',
        externalPublicDescriptor: 'ct-desc',
        internalPublicDescriptor: 'internal',
        created: created,
      ),
    ],
    derivationPath: "39'/0'/12'/101'",
    parentFingerprint: 'parent-fp',
    childSeedFingerprint: 'child-fp',
    childSeedStoredDuringAttempt: created,
  );
}
