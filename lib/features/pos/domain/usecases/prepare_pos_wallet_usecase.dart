import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/apply_wallet_behavior_defaults_usecase.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/deterministic_wallets/public/deterministic_wallets_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/pos/domain/pos_error.dart';
import 'package:bb_mobile/features/pos/domain/pos_wallet.dart';

const _posLiquidSpecId = 'pos-liquid';
const _posLiquidLabel = 'POS Liquid';
const _posScriptType = ScriptType.bip84;
const _posNetworkByEnvironment = <Environment, Network>{
  Environment.mainnet: Network.liquidMainnet,
  Environment.testnet: Network.liquidTestnet,
};

/// Prepares the Point of Sale wallet (BIP85 wallet-seed index 103) with the same
/// manifest-record-before-fundable + rollback + KC-6 posture guarantees the
/// Payment Page (102) and Lightning Address (101) wallets use. Idempotent: a
/// re-prepare returns the existing 103 wallet (the `created: false` path)
/// without re-deriving or re-recording.
class PreparePosWalletUsecase {
  final GetSettingsUsecase _getSettings;
  final DeterministicWalletsFacade _deterministicWallets;
  final KeychainManifestFacade _keychainManifest;
  final Bip85RegistryFacade _bip85Registry;
  final ApplyWalletBehaviorDefaultsUsecase _applyWalletBehaviorDefaults;

  const PreparePosWalletUsecase({
    required this._getSettings,
    required this._deterministicWallets,
    required this._keychainManifest,
    required this._applyWalletBehaviorDefaults,
    required this._bip85Registry,
  });

  Future<PreparedPosWallet> execute() async {
    PreparedDeterministicWallets? preparedWallets;
    var manifestRecorded = false;
    try {
      final settings = await _getSettings.execute();
      preparedWallets = await _deterministicWallets.prepare(
        _posWalletRequest(settings.environment),
      );
      await _recordKeychainManifestEntry(preparedWallets);
      manifestRecorded = true;
      final preparedWallet = preparedWallets.wallets.single;
      await _applyPosWalletDefaults(preparedWallet.walletId);
      return PreparedPosWallet(
        walletId: preparedWallet.walletId,
        ctDescriptor: preparedWallet.externalPublicDescriptor,
        created: preparedWallet.created,
      );
    } on PosException {
      if (preparedWallets != null && !manifestRecorded) {
        await _rollbackPreparedWalletsBestEffort(preparedWallets);
      }
      rethrow;
    } on DeterministicWalletException catch (e) {
      if (preparedWallets != null && !manifestRecorded) {
        await _rollbackPreparedWalletsBestEffort(preparedWallets);
      }
      if (e.type == DeterministicWalletExceptionType.generic) {
        throw const PosException.localPreparationFailed(
          code: 'DeterministicWalletPreparationFailed',
          retryable: true,
        );
      }
      throw const PosException.unexpected();
    } on KeychainManifestException catch (e) {
      if (preparedWallets != null && !manifestRecorded) {
        await _rollbackPreparedWalletsBestEffort(preparedWallets);
      }
      throw PosException.localPreparationFailed(
        code: 'KeychainManifestRecordFailed',
        retryable: _isRetryableManifestFailure(e),
      );
    } catch (_) {
      if (preparedWallets != null && !manifestRecorded) {
        await _rollbackPreparedWalletsBestEffort(preparedWallets);
      }
      throw const PosException.unexpected();
    }
  }

  DeterministicWalletsRequest _posWalletRequest(Environment environment) {
    final reservation = _bip85Registry.pointOfSaleWalletSeed;
    return DeterministicWalletsRequest(
      bip85Index: reservation.walletIndex,
      bip85Alias: reservation.deterministicAlias,
      environment: environment,
      walletSpecs: [
        DeterministicWalletSpec(
          id: _posLiquidSpecId,
          network: _networkForEnvironment(environment),
          scriptType: _posScriptType,
          label: _posLiquidLabel,
          isDefault: false,
          sync: false,
        ),
      ],
    );
  }

  Future<void> _recordKeychainManifestEntry(
    PreparedDeterministicWallets preparedWallets,
  ) {
    final reservation = _bip85Registry.pointOfSaleWalletSeed;
    final preparedWallet = preparedWallets.wallets.single;
    return _keychainManifest.recordReservedDerivation(
      KeychainManifestReservedDerivationRequest(
        reservationId: reservation.id,
        parentFingerprint: preparedWallets.parentFingerprint,
        derivationPath: preparedWallets.derivationPath,
        materializations: [
          KeychainManifestWalletMaterializationRequest(
            walletId: preparedWallet.walletId,
            childSeedFingerprint: preparedWallets.childSeedFingerprint,
            network: preparedWallet.network,
            scriptType: preparedWallet.scriptType,
          ),
        ],
      ),
    );
  }

  Future<void> _applyPosWalletDefaults(String walletId) async {
    try {
      await _applyWalletBehaviorDefaults.execute(
        walletId: walletId,
        hideOnHome: true,
        autoSweepEnabled: true,
      );
    } catch (e, stack) {
      log.warning('POS wallet defaults failed', error: e, trace: stack);
      throw const PosException.localPreparationFailed(
        code: 'WalletDefaultsFailed',
        retryable: true,
      );
    }
  }

  Network _networkForEnvironment(Environment environment) {
    final network = _posNetworkByEnvironment[environment];
    if (network == null) {
      throw const PosException.unexpected();
    }
    return network;
  }

  Future<void> _rollbackPreparedWalletsBestEffort(
    PreparedDeterministicWallets preparedWallets,
  ) async {
    try {
      await _deterministicWallets.rollbackCreatedWallets(preparedWallets);
    } catch (_) {
      // The caller still receives the original failure; cleanup is best effort.
    }
  }

  bool _isRetryableManifestFailure(KeychainManifestException error) {
    return switch (error.type) {
      KeychainManifestExceptionType.generic ||
      KeychainManifestExceptionType.fileParse ||
      KeychainManifestExceptionType.emptyInventory => true,
      KeychainManifestExceptionType.invalidEntry ||
      KeychainManifestExceptionType.reservationMismatch ||
      KeychainManifestExceptionType.unsupportedFileVersion ||
      KeychainManifestExceptionType.conflict ||
      KeychainManifestExceptionType.duplicate ||
      KeychainManifestExceptionType.backupSnapshot ||
      KeychainManifestExceptionType.remoteBackup => false,
    };
  }
}
