import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/keychain_recovery/application/ports/keychain_recovery_wallet_materializer_port.dart';
import 'package:bb_mobile/features/keychain_recovery/domain/keychain_recovery_result.dart';

class RestoreKeychainManifestWalletsUsecase {
  final KeychainRecoveryWalletMaterializerPort _walletMaterializer;
  final KeychainManifestFacade _keychainManifest;
  final Bip85RegistryFacade _registry;

  const RestoreKeychainManifestWalletsUsecase({
    required this._walletMaterializer,
    required this._keychainManifest,
    required Bip85RegistryFacade bip85Registry,
  }) : _registry = bip85Registry;

  Future<KeychainRecoveryResult> execute(
    KeychainManifestImportPlan importPlan,
  ) async {
    final outcomes = <KeychainRecoveryWalletRestoreOutcome>[];
    final entryIds = <String>{};
    final walletIds = <String>{};
    for (final entry in importPlan.entries) {
      final validationFailure = _validateEntry(
        importPlan: importPlan,
        entry: entry,
        entryIds: entryIds,
        walletIds: walletIds,
      );
      if (validationFailure != null) {
        outcomes.addAll(validationFailure);
        continue;
      }
      final batch = _materializationBatch(importPlan: importPlan, entry: entry);
      final materializationResult = await _materialize(batch);
      outcomes.addAll(materializationResult.failedOutcomes);
      outcomes.addAll(
        await _recordMaterializedWallets(
          parentFingerprint: importPlan.parentFingerprint,
          reservationId: entry.reservationId,
          materializationResult: materializationResult,
        ),
      );
    }
    return KeychainRecoveryResult(walletOutcomes: outcomes);
  }

  List<KeychainRecoveryWalletRestoreOutcome>? _validateEntry({
    required KeychainManifestImportPlan importPlan,
    required KeychainManifestImportEntryIntent entry,
    required Set<String> entryIds,
    required Set<String> walletIds,
  }) {
    final reservation = _registry.reservationById(entry.reservationId);
    if (reservation == null ||
        entryIds.contains(entry.entryId) ||
        entry.parentFingerprint != importPlan.parentFingerprint ||
        entry.entryId !=
            _entryId(importPlan.parentFingerprint, entry.bip85DerivationPath) ||
        !reservation.scope.matchesExactPath(entry.bip85DerivationPath)) {
      return _failedInvalidImportPlan(entry.walletMaterializations);
    }

    final walletKeys = <String>{};
    for (final intent in entry.walletMaterializations) {
      if (intent.entryId != entry.entryId ||
          intent.reservationId != entry.reservationId ||
          intent.bip85DerivationPath != entry.bip85DerivationPath ||
          !walletKeys.add(
            _materializationKey(
              entryId: intent.entryId,
              walletId: intent.walletId,
            ),
          ) ||
          walletIds.contains(intent.walletId)) {
        return _failedInvalidImportPlan(entry.walletMaterializations);
      }
    }
    entryIds.add(entry.entryId);
    walletIds.addAll(
      entry.walletMaterializations.map((intent) => intent.walletId),
    );
    return null;
  }

  KeychainRecoveryWalletMaterializationBatch _materializationBatch({
    required KeychainManifestImportPlan importPlan,
    required KeychainManifestImportEntryIntent entry,
  }) {
    final reservation = _registry.reservationById(entry.reservationId)!;
    return KeychainRecoveryWalletMaterializationBatch(
      parentFingerprint: importPlan.parentFingerprint,
      reservationId: entry.reservationId,
      bip85Index: reservation.walletIndex,
      deterministicAlias: reservation.deterministicAlias,
      intents: entry.walletMaterializations
          .map(_walletIntent)
          .toList(growable: false),
    );
  }

  KeychainRecoveryWalletIntent _walletIntent(
    KeychainManifestWalletMaterializationIntent intent,
  ) {
    return KeychainRecoveryWalletIntent(
      entryId: intent.entryId,
      reservationId: intent.reservationId,
      bip85DerivationPath: intent.bip85DerivationPath,
      walletId: intent.walletId,
      childSeedFingerprint: intent.childSeedFingerprint,
      network: intent.network,
      scriptType: intent.scriptType,
    );
  }

  List<KeychainRecoveryWalletRestoreOutcome> _failedInvalidImportPlan(
    List<KeychainManifestWalletMaterializationIntent> intents,
  ) {
    return intents
        .map(
          (intent) => KeychainRecoveryWalletRestoreOutcome(
            intent: _walletIntent(intent),
            status: KeychainRecoveryWalletRestoreStatus.failedInvalidImportPlan,
            walletId: intent.walletId,
          ),
        )
        .toList(growable: false);
  }

  String _entryId(String parentFingerprint, String bip85DerivationPath) {
    return '$parentFingerprint:$bip85DerivationPath';
  }

  String _materializationKey({
    required String entryId,
    required String walletId,
  }) {
    return '$entryId:$walletId';
  }

  Future<KeychainRecoveryWalletMaterializationResult> _materialize(
    KeychainRecoveryWalletMaterializationBatch batch,
  ) async {
    try {
      return await _walletMaterializer.materialize(batch);
    } catch (_) {
      return KeychainRecoveryWalletMaterializationResult(
        materializedWallets: const [],
        failedOutcomes: batch.intents
            .map(
              (intent) => KeychainRecoveryWalletRestoreOutcome(
                intent: intent,
                status:
                    KeychainRecoveryWalletRestoreStatus.failedWalletCreation,
                walletId: intent.walletId,
              ),
            )
            .toList(growable: false),
      );
    }
  }

  Future<List<KeychainRecoveryWalletRestoreOutcome>>
  _recordMaterializedWallets({
    required String parentFingerprint,
    required String reservationId,
    required KeychainRecoveryWalletMaterializationResult materializationResult,
  }) async {
    final wallets = materializationResult.materializedWallets;
    final derivationPath = materializationResult.derivationPath;
    if (wallets.isEmpty || derivationPath == null) return [];
    try {
      await _keychainManifest.recordReservedDerivation(
        KeychainManifestReservedDerivationRequest(
          reservationId: reservationId,
          parentFingerprint: parentFingerprint,
          derivationPath: derivationPath,
          materializations: wallets
              .map(
                (wallet) => KeychainManifestWalletMaterializationRequest(
                  walletId: wallet.walletId,
                  childSeedFingerprint: wallet.childSeedFingerprint,
                  network: wallet.intent.network,
                  scriptType: wallet.intent.scriptType,
                ),
              )
              .toList(growable: false),
        ),
      );
      return wallets
          .map((wallet) {
            return KeychainRecoveryWalletRestoreOutcome(
              intent: wallet.intent,
              status: _successStatus(wallet),
              walletId: wallet.walletId,
            );
          })
          .toList(growable: false);
    } on KeychainManifestException {
      final rollback = materializationResult.rollbackCreatedWallets;
      if (rollback != null) {
        try {
          await rollback();
        } catch (_) {
          // Preserve the recovery failure result; rollback is best effort here.
        }
      }
      return wallets
          .map((wallet) {
            return KeychainRecoveryWalletRestoreOutcome(
              intent: wallet.intent,
              status: KeychainRecoveryWalletRestoreStatus.failedManifestRecord,
              walletId: wallet.walletId,
            );
          })
          .toList(growable: false);
    }
  }

  KeychainRecoveryWalletRestoreStatus _successStatus(
    KeychainRecoveryMaterializedWallet wallet,
  ) {
    if (wallet.created) return KeychainRecoveryWalletRestoreStatus.created;
    return KeychainRecoveryWalletRestoreStatus.alreadyPresent;
  }
}
