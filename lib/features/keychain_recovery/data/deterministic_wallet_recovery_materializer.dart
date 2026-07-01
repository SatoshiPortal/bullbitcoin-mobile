import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/deterministic_wallets/public/deterministic_wallets_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/keychain_recovery/domain/keychain_recovery_result.dart';
import 'package:bb_mobile/features/keychain_recovery/domain/keychain_recovery_wallet_materializer_port.dart';

class DeterministicWalletRecoveryMaterializer
    implements KeychainRecoveryWalletMaterializerPort {
  final DeterministicWalletsFacade _deterministicWallets;
  final GetSettingsUsecase _getSettings;

  const DeterministicWalletRecoveryMaterializer({
    required this._deterministicWallets,
    required this._getSettings,
  });

  @override
  Future<KeychainRecoveryWalletMaterializationResult> materialize(
    KeychainRecoveryWalletMaterializationBatch batch,
  ) async {
    final settings = await _getSettings.execute();
    final supportedIntents = batch.intents
        .where(
          (intent) =>
              _networkMatchesEnvironment(intent.network, settings.environment),
        )
        .toList(growable: false);
    final unsupportedOutcomes = _unsupportedEnvironmentOutcomes(
      batch.intents,
      settings.environment,
    );
    if (supportedIntents.isEmpty) {
      return KeychainRecoveryWalletMaterializationResult(
        materializedWallets: const [],
        failedOutcomes: unsupportedOutcomes,
      );
    }

    PreparedDeterministicWallets? prepared;
    try {
      prepared = await _deterministicWallets.prepare(
        DeterministicWalletsRequest(
          bip85Index: batch.bip85Index,
          bip85Alias: batch.deterministicAlias,
          environment: settings.environment,
          walletSpecs: supportedIntents
              .map(
                (intent) => DeterministicWalletSpec(
                  id: _materializationKey(intent),
                  network: intent.network,
                  scriptType: intent.scriptType,
                  isDefault: false,
                  sync: false,
                ),
              )
              .toList(growable: false),
        ),
      );
    } catch (_) {
      return KeychainRecoveryWalletMaterializationResult(
        materializedWallets: const [],
        failedOutcomes: [
          ...unsupportedOutcomes,
          ..._failed(supportedIntents, status: _failedWalletCreation),
        ],
      );
    }

    if (prepared.parentFingerprint.toLowerCase() !=
        batch.parentFingerprint.toLowerCase()) {
      await _rollbackCreatedWalletsBestEffort(prepared);
      return KeychainRecoveryWalletMaterializationResult(
        materializedWallets: const [],
        failedOutcomes: [
          ...unsupportedOutcomes,
          ..._failed(supportedIntents, status: _parentFingerprintMismatch),
        ],
      );
    }

    final childFingerprintMismatches = supportedIntents
        .where(
          (intent) =>
              intent.childSeedFingerprint.toLowerCase() !=
              prepared!.childSeedFingerprint.toLowerCase(),
        )
        .toList(growable: false);
    if (childFingerprintMismatches.isNotEmpty) {
      await _rollbackCreatedWalletsBestEffort(prepared);
      return KeychainRecoveryWalletMaterializationResult(
        materializedWallets: const [],
        failedOutcomes: [
          ...unsupportedOutcomes,
          ..._failed(supportedIntents, status: _childSeedFingerprintMismatch),
        ],
      );
    }

    final materialized = <KeychainRecoveryMaterializedWallet>[];
    var hasConflict = false;
    for (final intent in supportedIntents) {
      final preparedWallet = prepared.wallets.firstWhere(
        (wallet) => wallet.specId == _materializationKey(intent),
      );
      if (preparedWallet.walletId != intent.walletId) {
        hasConflict = true;
        continue;
      }
      materialized.add(
        KeychainRecoveryMaterializedWallet(
          intent: intent,
          childSeedFingerprint: prepared.childSeedFingerprint,
          created: preparedWallet.created,
        ),
      );
    }
    if (hasConflict) {
      await _rollbackCreatedWalletsBestEffort(prepared);
      return KeychainRecoveryWalletMaterializationResult(
        materializedWallets: const [],
        failedOutcomes: [
          ...unsupportedOutcomes,
          ..._failed(supportedIntents, status: _failedConflict),
        ],
      );
    }
    return KeychainRecoveryWalletMaterializationResult(
      materializedWallets: materialized,
      failedOutcomes: unsupportedOutcomes,
      derivationPath: prepared.derivationPath,
    );
  }

  Future<void> _rollbackCreatedWalletsBestEffort(
    PreparedDeterministicWallets prepared,
  ) async {
    try {
      await _deterministicWallets.rollbackCreatedWallets(prepared);
    } catch (_) {
      // Recovery still reports the materialization failure; rollback is best effort.
    }
  }

  List<KeychainRecoveryWalletRestoreOutcome> _unsupportedEnvironmentOutcomes(
    List<KeychainManifestWalletMaterializationIntent> intents,
    Environment environment,
  ) {
    return intents
        .where(
          (intent) => !_networkMatchesEnvironment(intent.network, environment),
        )
        .map(
          (intent) => KeychainRecoveryWalletRestoreOutcome(
            intent: intent,
            status: KeychainRecoveryWalletRestoreStatus.skippedUnsupported,
          ),
        )
        .toList(growable: false);
  }

  bool _networkMatchesEnvironment(Network network, Environment environment) {
    return switch (environment) {
      Environment.mainnet => network.isMainnet,
      Environment.testnet => network.isTestnet,
    };
  }

  String _materializationKey(
    KeychainManifestWalletMaterializationIntent intent,
  ) {
    return '${intent.entryId}:${intent.walletId}';
  }

  List<KeychainRecoveryWalletRestoreOutcome> _failed(
    List<KeychainManifestWalletMaterializationIntent> intents, {
    required KeychainRecoveryWalletRestoreStatus status,
  }) {
    return intents
        .map(
          (intent) => KeychainRecoveryWalletRestoreOutcome(
            intent: intent,
            status: status,
          ),
        )
        .toList(growable: false);
  }
}

const _failedWalletCreation =
    KeychainRecoveryWalletRestoreStatus.failedWalletCreation;
const _parentFingerprintMismatch =
    KeychainRecoveryWalletRestoreStatus.failedParentFingerprintMismatch;
const _childSeedFingerprintMismatch =
    KeychainRecoveryWalletRestoreStatus.failedChildSeedFingerprintMismatch;
const _failedConflict = KeychainRecoveryWalletRestoreStatus.failedConflict;
