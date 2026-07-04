import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/apply_wallet_behavior_defaults_usecase.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/keychain_recovery/domain/keychain_recovery_result.dart';
import 'package:bb_mobile/features/keychain_recovery/domain/keychain_recovery_wallet_materializer_port.dart';
import 'package:bb_mobile/features/keychain_recovery/domain/restore_keychain_manifest_wallets_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeWalletMaterializer materializer;
  late _FakeKeychainManifestFacade keychainManifest;
  late _FakeApplyWalletBehaviorDefaults applyDefaults;
  late RestoreKeychainManifestWalletsUsecase usecase;

  setUp(() {
    materializer = _FakeWalletMaterializer();
    keychainManifest = _FakeKeychainManifestFacade();
    applyDefaults = _FakeApplyWalletBehaviorDefaults();
    usecase = RestoreKeychainManifestWalletsUsecase(
      walletMaterializer: materializer,
      keychainManifest: keychainManifest,
      applyWalletBehaviorDefaults: applyDefaults,
      bip85Registry: const Bip85RegistryFacade(),
    );
  });

  test('records and reports restored wallet materializations', () async {
    final intent = _intent();
    materializer.result = KeychainRecoveryWalletMaterializationResult(
      materializedWallets: [
        KeychainRecoveryMaterializedWallet(
          intent: intent,
          childSeedFingerprint: intent.childSeedFingerprint,
          created: true,
        ),
      ],
      failedOutcomes: const [],
      derivationPath: "39'/0'/12'/100'",
    );

    final result = await usecase.execute(_plan(intent));

    expect(result.hasFailures, false);
    expect(result.walletOutcomes.single.status, _created);
    expect(materializer.batches.single.deterministicAlias, 'BTCPay');
    expect(
      keychainManifest.recordRequests.single.reservationId,
      intent.reservationId,
    );
    final requestMaterialization =
        keychainManifest.recordRequests.single.materializations.single;
    expect(requestMaterialization.walletId, intent.walletId);
  });

  test('preserves materializer failures without recording metadata', () async {
    final intent = _intent();
    materializer.result = KeychainRecoveryWalletMaterializationResult(
      materializedWallets: const [],
      failedOutcomes: [
        KeychainRecoveryWalletRestoreOutcome(
          intent: intent,
          status: KeychainRecoveryWalletRestoreStatus.skippedUnsupported,
        ),
      ],
    );

    final result = await usecase.execute(_plan(intent));

    expect(result.hasFailures, true);
    expect(result.walletOutcomes.single.status, _skipped);
    expect(keychainManifest.recordRequests, isEmpty);
  });

  test('reports manifest record failures per materialized wallet', () async {
    final intent = _intent();
    final liquidIntent = _intent(
      walletId: 'lbtc-wallet',
      network: Network.liquidMainnet,
    );
    keychainManifest.recordError = KeychainManifestFileParseException(
      reason: KeychainManifestFileParseFailureReason.invalidMetadata,
    );
    materializer.result = KeychainRecoveryWalletMaterializationResult(
      materializedWallets: [
        KeychainRecoveryMaterializedWallet(
          intent: intent,
          childSeedFingerprint: intent.childSeedFingerprint,
          created: true,
        ),
        KeychainRecoveryMaterializedWallet(
          intent: liquidIntent,
          childSeedFingerprint: liquidIntent.childSeedFingerprint,
          created: true,
        ),
      ],
      failedOutcomes: const [],
      derivationPath: "39'/0'/12'/100'",
    );

    final result = await usecase.execute(_plan(intent, liquidIntent));

    expect(result.hasFailures, true);
    expect(result.walletOutcomes.map((outcome) => outcome.status), [
      _recordFailed,
      _recordFailed,
    ]);
  });

  test(
    'reports existing wallets as already present after manifest recording',
    () async {
      final intent = _intent();
      materializer.result = KeychainRecoveryWalletMaterializationResult(
        materializedWallets: [
          KeychainRecoveryMaterializedWallet(
            intent: intent,
            childSeedFingerprint: intent.childSeedFingerprint,
            created: false,
          ),
        ],
        failedOutcomes: const [],
        derivationPath: "39'/0'/12'/100'",
      );

      final result = await usecase.execute(_plan(intent));

      expect(result.hasFailures, false);
      expect(result.walletOutcomes.single.status, _alreadyPresent);
    },
  );

  test('rejects forged import plans before wallet materialization', () async {
    final intent = _intent();
    final forgedIntent = KeychainManifestWalletMaterializationIntent(
      entryId: intent.entryId,
      reservationId: intent.reservationId,
      bip85DerivationPath: intent.bip85DerivationPath,
      walletId: intent.walletId,
      childSeedFingerprint: intent.childSeedFingerprint,
      network: intent.network,
      scriptType: intent.scriptType,
    );
    final forgedPlan = KeychainManifestImportPlan(
      parentFingerprint: 'fedcba98',
      entries: [
        KeychainManifestImportEntryIntent(
          entryId: "fedcba98:39'/0'/12'/101'",
          parentFingerprint: 'fedcba98',
          bip85DerivationPath: "39'/0'/12'/100'",
          reservationId: 'btcpay_wallet_seed',
          walletMaterializations: [forgedIntent],
        ),
      ],
    );

    final result = await usecase.execute(forgedPlan);

    expect(result.hasFailures, true);
    expect(result.walletOutcomes.single.status, _invalidImportPlan);
    expect(materializer.batches, isEmpty);
    expect(keychainManifest.recordRequests, isEmpty);
  });

  test(
    're-applies the hidden + autosweep Get Paid posture to each wallet',
    () async {
      final intent = _intent();
      materializer.result = KeychainRecoveryWalletMaterializationResult(
        materializedWallets: [
          KeychainRecoveryMaterializedWallet(
            intent: intent,
            childSeedFingerprint: intent.childSeedFingerprint,
            created: true,
          ),
        ],
        failedOutcomes: const [],
        derivationPath: "39'/0'/12'/100'",
      );

      await usecase.execute(_plan(intent));

      expect(applyDefaults.calls.single.walletId, intent.walletId);
      expect(applyDefaults.calls.single.hideOnHome, true);
      expect(applyDefaults.calls.single.autoSweepEnabled, true);
    },
  );

  test('a posture-defaults failure does not fail the restore', () async {
    final intent = _intent();
    applyDefaults.throwOnExecute = true;
    materializer.result = KeychainRecoveryWalletMaterializationResult(
      materializedWallets: [
        KeychainRecoveryMaterializedWallet(
          intent: intent,
          childSeedFingerprint: intent.childSeedFingerprint,
          created: true,
        ),
      ],
      failedOutcomes: const [],
      derivationPath: "39'/0'/12'/100'",
    );

    final result = await usecase.execute(_plan(intent));

    // Post-commitment (manifest already recorded): the wallet is restored even
    // though re-applying the posture threw.
    expect(result.hasFailures, false);
    expect(result.walletOutcomes.single.status, _created);
  });

  test('an empty import plan reports nothing restored, not success', () async {
    final emptyPlan = KeychainManifestImportPlan(
      parentFingerprint: 'fedcba98',
      entries: const [],
    );

    final result = await usecase.execute(emptyPlan);

    expect(result.walletOutcomes, isEmpty);
    expect(result.hasFailures, false);
    expect(result.restoredCount, 0);
    expect(result.restoredNothing, true);
  });

  test('refuses an entry whose reservation id is unknown', () async {
    final intent = _intent();
    final plan = KeychainManifestImportPlan(
      parentFingerprint: 'fedcba98',
      entries: [
        KeychainManifestImportEntryIntent(
          entryId: "fedcba98:39'/0'/12'/100'",
          parentFingerprint: 'fedcba98',
          bip85DerivationPath: "39'/0'/12'/100'",
          reservationId: 'unknown_wallet_seed',
          walletMaterializations: [intent],
        ),
      ],
    );

    final result = await usecase.execute(plan);

    expect(result.walletOutcomes.single.status, _invalidImportPlan);
    expect(materializer.batches, isEmpty);
  });

  test('refuses an entry whose path is not the reservation path', () async {
    final intent = _intent();
    final plan = KeychainManifestImportPlan(
      parentFingerprint: 'fedcba98',
      entries: [
        KeychainManifestImportEntryIntent(
          entryId: "fedcba98:39'/0'/12'/77'",
          parentFingerprint: 'fedcba98',
          bip85DerivationPath: "39'/0'/12'/77'",
          reservationId: 'btcpay_wallet_seed',
          walletMaterializations: [intent],
        ),
      ],
    );

    final result = await usecase.execute(plan);

    expect(result.walletOutcomes.single.status, _invalidImportPlan);
    expect(materializer.batches, isEmpty);
  });
}

KeychainManifestImportPlan _plan(
  KeychainManifestWalletMaterializationIntent intent, [
  KeychainManifestWalletMaterializationIntent? secondIntent,
]) {
  return KeychainManifestImportPlan(
    parentFingerprint: 'fedcba98',
    entries: [
      KeychainManifestImportEntryIntent(
        entryId: "fedcba98:39'/0'/12'/100'",
        parentFingerprint: 'fedcba98',
        bip85DerivationPath: "39'/0'/12'/100'",
        reservationId: 'btcpay_wallet_seed',
        walletMaterializations: [intent, ?secondIntent],
      ),
    ],
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

class _FakeWalletMaterializer
    implements KeychainRecoveryWalletMaterializerPort {
  final batches = <KeychainRecoveryWalletMaterializationBatch>[];
  late KeychainRecoveryWalletMaterializationResult result;

  @override
  Future<KeychainRecoveryWalletMaterializationResult> materialize(
    KeychainRecoveryWalletMaterializationBatch batch,
  ) async {
    batches.add(batch);
    return result;
  }
}

class _FakeKeychainManifestFacade implements KeychainManifestFacade {
  final recordRequests = <KeychainManifestReservedDerivationRequest>[];
  KeychainManifestException? recordError;

  @override
  Future<void> recordReservedDerivation(
    KeychainManifestReservedDerivationRequest request, {
    DateTime? now,
  }) async {
    final error = recordError;
    if (error != null) throw error;
    recordRequests.add(request);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeApplyWalletBehaviorDefaults
    implements ApplyWalletBehaviorDefaultsUsecase {
  final calls =
      <({String walletId, bool? hideOnHome, bool? autoSweepEnabled})>[];
  bool throwOnExecute = false;

  @override
  Future<void> execute({
    required String walletId,
    bool? hideOnHome,
    bool? autoSweepEnabled,
  }) async {
    calls.add((
      walletId: walletId,
      hideOnHome: hideOnHome,
      autoSweepEnabled: autoSweepEnabled,
    ));
    if (throwOnExecute) throw StateError('defaults failed');
  }
}

const _created = KeychainRecoveryWalletRestoreStatus.created;
const _alreadyPresent = KeychainRecoveryWalletRestoreStatus.alreadyPresent;
const _skipped = KeychainRecoveryWalletRestoreStatus.skippedUnsupported;
const _invalidImportPlan =
    KeychainRecoveryWalletRestoreStatus.failedInvalidImportPlan;
const _recordFailed = KeychainRecoveryWalletRestoreStatus.failedManifestRecord;
