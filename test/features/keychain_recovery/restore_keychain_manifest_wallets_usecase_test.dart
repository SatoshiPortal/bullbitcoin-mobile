import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/keychain_recovery/application/ports/keychain_recovery_wallet_materializer_port.dart';
import 'package:bb_mobile/features/keychain_recovery/application/usecases/restore_keychain_manifest_wallets_usecase.dart';
import 'package:bb_mobile/features/keychain_recovery/domain/keychain_recovery_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeWalletMaterializer materializer;
  late _FakeKeychainManifestFacade keychainManifest;
  late RestoreKeychainManifestWalletsUsecase usecase;

  setUp(() {
    materializer = _FakeWalletMaterializer();
    keychainManifest = _FakeKeychainManifestFacade();
    usecase = RestoreKeychainManifestWalletsUsecase(
      walletMaterializer: materializer,
      keychainManifest: keychainManifest,
      bip85Registry: const Bip85RegistryFacade(),
    );
  });

  test('records and reports restored wallet materializations', () async {
    final intent = _intent();
    materializer.result = KeychainRecoveryWalletMaterializationResult(
      materializedWallets: [
        KeychainRecoveryMaterializedWallet(
          intent: intent,
          walletId: intent.walletId,
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
          walletId: intent.walletId,
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
    keychainManifest.recordError = KeychainManifestException.fromInternal(
      Exception('failed'),
    );
    materializer.result = KeychainRecoveryWalletMaterializationResult(
      materializedWallets: [
        KeychainRecoveryMaterializedWallet(
          intent: intent,
          walletId: intent.walletId,
          childSeedFingerprint: intent.childSeedFingerprint,
          created: false,
        ),
      ],
      failedOutcomes: const [],
      derivationPath: "39'/0'/12'/100'",
    );

    final result = await usecase.execute(_plan(intent));

    expect(result.hasFailures, true);
    expect(result.walletOutcomes.single.status, _recordFailed);
  });
}

KeychainManifestImportPlan _plan(
  KeychainManifestWalletMaterializationIntent intent,
) {
  return KeychainManifestImportPlan(
    parentFingerprint: 'fedcba98',
    entries: [
      KeychainManifestImportEntryIntent(
        entryId: "fedcba98:39'/0'/12'/100'",
        parentFingerprint: 'fedcba98',
        bip85DerivationPath: "39'/0'/12'/100'",
        reservationId: 'btcpay_wallet_seed',
        walletMaterializations: [intent],
      ),
    ],
  );
}

KeychainManifestWalletMaterializationIntent _intent() {
  return KeychainManifestWalletMaterializationIntent(
    entryId: "fedcba98:39'/0'/12'/100'",
    reservationId: 'btcpay_wallet_seed',
    bip85DerivationPath: "39'/0'/12'/100'",
    walletId: 'btc-wallet',
    childSeedFingerprint: '0123abcd',
    network: Network.bitcoinMainnet,
    scriptType: ScriptType.bip84,
  );
}


class _FakeWalletMaterializer
    implements KeychainRecoveryWalletMaterializerPort {
  late KeychainRecoveryWalletMaterializationResult result;

  @override
  Future<KeychainRecoveryWalletMaterializationResult> materialize(
    KeychainRecoveryWalletMaterializationBatch batch,
  ) async {
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

const _created = KeychainRecoveryWalletRestoreStatus.created;
const _skipped = KeychainRecoveryWalletRestoreStatus.skippedUnsupported;
const _recordFailed = KeychainRecoveryWalletRestoreStatus.failedManifestRecord;
