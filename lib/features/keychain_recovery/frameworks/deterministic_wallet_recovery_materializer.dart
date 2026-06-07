import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/deterministic_wallets/public/deterministic_wallets_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/keychain_recovery/application/ports/keychain_recovery_wallet_materializer_port.dart';
import 'package:bb_mobile/features/keychain_recovery/domain/keychain_recovery_result.dart';

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
    final unsupported = _unsupportedEnvironmentOutcomes(
      batch.intents,
      settings.environment,
    );
    if (unsupported.isNotEmpty) {
      return KeychainRecoveryWalletMaterializationResult(
        materializedWallets: const [],
        failedOutcomes: unsupported,
      );
    }

    PreparedDeterministicWallets? prepared;
    try {
      prepared = await _deterministicWallets.prepare(
        DeterministicWalletsRequest(
          bip85Index: batch.bip85Index,
          bip85Alias: batch.reservationId,
          environment: settings.environment,
          walletSpecs: batch.intents
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
        failedOutcomes: _failed(batch.intents, status: _failedWalletCreation),
      );
    }

    if (prepared.parentFingerprint.toLowerCase() !=
        batch.parentFingerprint.toLowerCase()) {
      await _deterministicWallets.rollbackCreatedWallets(prepared);
      return KeychainRecoveryWalletMaterializationResult(
        materializedWallets: const [],
        failedOutcomes: _failed(
          batch.intents,
          status: _parentFingerprintMismatch,
        ),
      );
    }

    final materialized = <KeychainRecoveryMaterializedWallet>[];
    final failures = <KeychainRecoveryWalletRestoreOutcome>[];
    for (final intent in batch.intents) {
      final preparedWallet = prepared.wallets.firstWhere(
        (wallet) => wallet.specId == _materializationKey(intent),
      );
      if (preparedWallet.walletId != intent.walletId) {
        failures.add(
          KeychainRecoveryWalletRestoreOutcome(
            intent: intent,
            status: KeychainRecoveryWalletRestoreStatus.failedConflict,
            walletId: preparedWallet.walletId,
          ),
        );
        continue;
      }
      materialized.add(
        KeychainRecoveryMaterializedWallet(
          intent: intent,
          walletId: preparedWallet.walletId,
          childSeedFingerprint: prepared.childSeedFingerprint,
          created: preparedWallet.created,
        ),
      );
    }
    if (failures.isNotEmpty) {
      await _deterministicWallets.rollbackCreatedWallets(prepared);
      return KeychainRecoveryWalletMaterializationResult(
        materializedWallets: const [],
        failedOutcomes: failures,
      );
    }
    return KeychainRecoveryWalletMaterializationResult(
      materializedWallets: materialized,
      failedOutcomes: const [],
      derivationPath: prepared.derivationPath,
    );
  }

  String _materializationKey(
    KeychainManifestWalletMaterializationIntent intent,
  ) {
    return '${intent.entryId}:${intent.walletId}';
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
            walletId: intent.walletId,
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

  List<KeychainRecoveryWalletRestoreOutcome> _failed(
    List<KeychainManifestWalletMaterializationIntent> intents, {
    required KeychainRecoveryWalletRestoreStatus status,
  }) {
    return intents
        .map(
          (intent) => KeychainRecoveryWalletRestoreOutcome(
            intent: intent,
            status: status,
            walletId: intent.walletId,
          ),
        )
        .toList(growable: false);
  }
}

const _failedWalletCreation =
    KeychainRecoveryWalletRestoreStatus.failedWalletCreation;
const _parentFingerprintMismatch =
    KeychainRecoveryWalletRestoreStatus.failedParentFingerprintMismatch;
