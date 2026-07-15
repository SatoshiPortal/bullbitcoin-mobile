import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/deterministic_wallets/public/deterministic_wallets_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/keychain_recovery/data/deterministic_wallet_recovery_materializer.dart';
import 'package:bb_mobile/features/keychain_recovery/domain/keychain_recovery_result.dart';
import 'package:bb_mobile/features/keychain_recovery/domain/keychain_recovery_wallet_materializer_port.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeDeterministicWalletsFacade deterministicWallets;
  late _FakeGetSettingsUsecase getSettings;
  late DeterministicWalletRecoveryMaterializer materializer;

  setUp(() {
    deterministicWallets = _FakeDeterministicWalletsFacade();
    getSettings = _FakeGetSettingsUsecase(Environment.mainnet);
    materializer = DeterministicWalletRecoveryMaterializer(
      deterministicWallets: deterministicWallets,
      getSettings: getSettings,
    );
  });

  test(
    'uses reservation alias and skips unsupported networks per wallet',
    () async {
      final supported = _intent(walletId: 'btc-wallet');
      final unsupported = _intent(
        walletId: 'testnet-wallet',
        network: Network.bitcoinTestnet,
      );
      deterministicWallets.result = _prepared(
        childSeedFingerprint: '0123abcd',
        wallets: [
          PreparedDeterministicWallet(
            specId: _materializationKey(supported),
            walletId: supported.walletId,
            network: supported.network,
            scriptType: supported.scriptType,
            externalPublicDescriptor: 'external',
            internalPublicDescriptor: 'internal',
            created: true,
          ),
        ],
      );

      final result = await materializer.materialize(
        _batch(intents: [supported, unsupported]),
      );

      expect(deterministicWallets.requests.single.bip85Alias, 'BTCPay');
      expect(deterministicWallets.requests.single.walletSpecs, hasLength(1));
      expect(result.materializedWallets.single.intent.walletId, 'btc-wallet');
      expect(result.failedOutcomes.single.intent.walletId, 'testnet-wallet');
      expect(result.failedOutcomes.single.status, _skipped);
    },
  );

  test(
    'rolls back and fails the batch on parent fingerprint mismatch',
    () async {
      // The primary anti-wrong-wallet defense: the seed the app derived from
      // must be the seed the manifest was built under, or nothing is restored.
      final intent = _intent();
      deterministicWallets.result = _prepared(
        parentFingerprint: 'deadbeef',
        childSeedFingerprint: '0123abcd',
        wallets: [
          PreparedDeterministicWallet(
            specId: _materializationKey(intent),
            walletId: intent.walletId,
            network: intent.network,
            scriptType: intent.scriptType,
            externalPublicDescriptor: 'external',
            internalPublicDescriptor: 'internal',
            created: true,
          ),
        ],
      );

      final result = await materializer.materialize(_batch(intents: [intent]));

      expect(result.materializedWallets, isEmpty);
      expect(
        result.failedOutcomes.single.status,
        KeychainRecoveryWalletRestoreStatus.failedParentFingerprintMismatch,
      );
      expect(deterministicWallets.rollbackCalls, 1);
    },
  );

  test(
    'rolls back and fails supported batch on child fingerprint mismatch',
    () async {
      final intent = _intent();
      deterministicWallets.result = _prepared(
        childSeedFingerprint: 'deadbeef',
        wallets: [
          PreparedDeterministicWallet(
            specId: _materializationKey(intent),
            walletId: intent.walletId,
            network: intent.network,
            scriptType: intent.scriptType,
            externalPublicDescriptor: 'external',
            internalPublicDescriptor: 'internal',
            created: true,
          ),
        ],
      );

      final result = await materializer.materialize(_batch(intents: [intent]));

      expect(result.materializedWallets, isEmpty);
      expect(result.failedOutcomes.single.status, _childFingerprintMismatch);
      expect(deterministicWallets.rollbackCalls, 1);
    },
  );

  test('maps typed wallet preparation failures without throwing', () async {
    final intent = _intent();
    deterministicWallets.prepareFailure =
        const DeterministicWalletDerivationFailure();

    final result = await materializer.materialize(_batch(intents: [intent]));

    expect(result.materializedWallets, isEmpty);
    expect(result.failedOutcomes.single.status, _walletCreationFailed);
    expect(deterministicWallets.rollbackCalls, 0);
  });

  test(
    'rolls back and reports all supported wallets on wallet id conflict',
    () async {
      final first = _intent(walletId: 'btc-wallet');
      final second = _intent(
        walletId: 'lbtc-wallet',
        network: Network.liquidMainnet,
      );
      deterministicWallets.result = _prepared(
        childSeedFingerprint: '0123abcd',
        wallets: [
          PreparedDeterministicWallet(
            specId: _materializationKey(first),
            walletId: 'other-wallet',
            network: first.network,
            scriptType: first.scriptType,
            externalPublicDescriptor: 'external',
            internalPublicDescriptor: 'internal',
            created: true,
          ),
          PreparedDeterministicWallet(
            specId: _materializationKey(second),
            walletId: second.walletId,
            network: second.network,
            scriptType: second.scriptType,
            externalPublicDescriptor: 'external',
            internalPublicDescriptor: 'internal',
            created: true,
          ),
        ],
      );

      final result = await materializer.materialize(
        _batch(intents: [first, second]),
      );

      expect(result.materializedWallets, isEmpty);
      expect(result.failedOutcomes.map((outcome) => outcome.status), [
        _conflict,
        _conflict,
      ]);
      expect(result.failedOutcomes.map((outcome) => outcome.walletId), [
        'btc-wallet',
        'lbtc-wallet',
      ]);
      expect(deterministicWallets.rollbackCalls, 1);
    },
  );
}

KeychainRecoveryWalletMaterializationBatch _batch({
  required List<KeychainManifestWalletMaterializationIntent> intents,
}) {
  return KeychainRecoveryWalletMaterializationBatch(
    parentFingerprint: 'fedcba98',
    bip85Index: 100,
    deterministicAlias: 'BTCPay',
    intents: intents,
  );
}

KeychainManifestWalletMaterializationIntent _intent({
  String walletId = 'btc-wallet',
  Network network = Network.bitcoinMainnet,
}) {
  return KeychainManifestWalletMaterializationIntent(
    entryId: "fedcba98:39'/0'/12'/100'",
    reservationId: 'btcpay_wallet_seed',
    bip85DerivationPath: "39'/0'/12'/100'",
    walletId: walletId,
    childSeedFingerprint: '0123abcd',
    network: network,
    scriptType: ScriptType.bip84,
  );
}

String _materializationKey(KeychainManifestWalletMaterializationIntent intent) {
  return '${intent.entryId}:${intent.walletId}';
}

PreparedDeterministicWallets _prepared({
  required String childSeedFingerprint,
  required List<PreparedDeterministicWallet> wallets,
  String parentFingerprint = 'fedcba98',
}) {
  return PreparedDeterministicWallets(
    wallets: wallets,
    derivationPath: "39'/0'/12'/100'",
    parentFingerprint: parentFingerprint,
    childSeedFingerprint: childSeedFingerprint,
    childSeedStoredDuringAttempt: true,
  );
}

class _FakeDeterministicWalletsFacade implements DeterministicWalletsFacade {
  final requests = <DeterministicWalletsRequest>[];
  late PreparedDeterministicWallets result;
  DeterministicWalletFailure? prepareFailure;
  DeterministicWalletFailure? rollbackFailure;
  int rollbackCalls = 0;

  @override
  Future<Result<PreparedDeterministicWallets, DeterministicWalletFailure>>
  prepare(DeterministicWalletsRequest request) async {
    requests.add(request);
    final failure = prepareFailure;
    return failure == null ? Ok(result) : Err(failure);
  }

  @override
  Future<Result<void, DeterministicWalletFailure>> rollbackCreatedWallets(
    PreparedDeterministicWallets result,
  ) async {
    rollbackCalls++;
    final failure = rollbackFailure;
    return failure == null ? const Ok(null) : Err(failure);
  }
}

class _FakeGetSettingsUsecase implements GetSettingsUsecase {
  final Environment environment;

  const _FakeGetSettingsUsecase(this.environment);

  @override
  Future<SettingsEntity> execute() async {
    return SettingsEntity(
      environment: environment,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'USD',
    );
  }
}

const _skipped = KeychainRecoveryWalletRestoreStatus.skippedUnsupported;
const _walletCreationFailed =
    KeychainRecoveryWalletRestoreStatus.failedWalletCreation;
const _childFingerprintMismatch =
    KeychainRecoveryWalletRestoreStatus.failedChildSeedFingerprintMismatch;
const _conflict = KeychainRecoveryWalletRestoreStatus.failedConflict;
