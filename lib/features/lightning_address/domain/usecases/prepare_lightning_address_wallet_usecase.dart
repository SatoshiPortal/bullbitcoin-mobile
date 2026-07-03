import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/apply_wallet_behavior_defaults_usecase.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/deterministic_wallets/public/deterministic_wallets_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_wallet.dart';

const _lightningAddressLiquidSpecId = 'lightning-address-liquid';
const _lightningAddressLiquidLabel = 'Lightning Address Liquid';
const _lightningAddressScriptType = ScriptType.bip84;
const _lightningAddressNetworkByEnvironment = <Environment, Network>{
  Environment.mainnet: Network.liquidMainnet,
  Environment.testnet: Network.liquidTestnet,
};

class PrepareLightningAddressWalletUsecase {
  final GetSettingsUsecase _getSettings;
  final DeterministicWalletsFacade _deterministicWallets;
  final KeychainManifestFacade _keychainManifest;
  final Bip85RegistryFacade _bip85Registry;
  final ApplyWalletBehaviorDefaultsUsecase _applyWalletBehaviorDefaults;

  const PrepareLightningAddressWalletUsecase({
    required this._getSettings,
    required this._deterministicWallets,
    required this._keychainManifest,
    required this._applyWalletBehaviorDefaults,
    required this._bip85Registry,
  });

  Future<PreparedLightningAddressWallet> execute() async {
    PreparedDeterministicWallets? preparedWallets;
    var manifestRecorded = false;
    try {
      final settings = await _getSettings.execute();
      final prepareResult = await _deterministicWallets.prepare(
        _lightningAddressWalletRequest(settings.environment),
      );
      switch (prepareResult) {
        case Ok(:final value):
          preparedWallets = value;
        case Err(:final failure):
          throw _mapDeterministicWalletFailure(failure);
      }
      await _recordKeychainManifestEntry(preparedWallets);
      manifestRecorded = true;
      final preparedWallet = preparedWallets.wallets.single;
      await _applyLightningAddressWalletDefaults(preparedWallet.walletId);
      return PreparedLightningAddressWallet(
        walletId: preparedWallet.walletId,
        ctDescriptor: preparedWallet.externalPublicDescriptor,
        created: preparedWallet.created,
      );
    } on LightningAddressException {
      if (preparedWallets != null && !manifestRecorded) {
        await _rollbackPreparedWalletsBestEffort(preparedWallets);
      }
      rethrow;
    } on KeychainManifestException catch (e) {
      if (preparedWallets != null && !manifestRecorded) {
        await _rollbackPreparedWalletsBestEffort(preparedWallets);
      }
      throw LightningAddressException.localPreparationFailed(
        code: 'KeychainManifestRecordFailed',
        retryable: _isRetryableManifestFailure(e),
      );
    } catch (_) {
      if (preparedWallets != null && !manifestRecorded) {
        await _rollbackPreparedWalletsBestEffort(preparedWallets);
      }
      throw const LightningAddressException.unexpected();
    }
  }

  DeterministicWalletsRequest _lightningAddressWalletRequest(
    Environment environment,
  ) {
    final reservation = _bip85Registry.lightningAddressWalletSeed;
    return DeterministicWalletsRequest(
      bip85Index: reservation.walletIndex,
      bip85Alias: reservation.deterministicAlias,
      environment: environment,
      walletSpecs: [
        DeterministicWalletSpec(
          id: _lightningAddressLiquidSpecId,
          network: _networkForEnvironment(environment),
          scriptType: _lightningAddressScriptType,
          label: _lightningAddressLiquidLabel,
          isDefault: false,
          sync: false,
        ),
      ],
    );
  }

  Future<void> _recordKeychainManifestEntry(
    PreparedDeterministicWallets preparedWallets,
  ) {
    final reservation = _bip85Registry.lightningAddressWalletSeed;
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

  Future<void> _applyLightningAddressWalletDefaults(String walletId) async {
    try {
      await _applyWalletBehaviorDefaults.execute(
        walletId: walletId,
        hideOnHome: true,
        autoSweepEnabled: true,
      );
    } catch (e) {
      throw const LightningAddressException.localPreparationFailed(
        code: 'WalletDefaultsFailed',
        retryable: true,
      );
    }
  }

  Network _networkForEnvironment(Environment environment) {
    final network = _lightningAddressNetworkByEnvironment[environment];
    if (network == null) {
      throw const LightningAddressException.unexpected();
    }
    return network;
  }

  Future<void> _rollbackPreparedWalletsBestEffort(
    PreparedDeterministicWallets preparedWallets,
  ) async {
    try {
      final result = await _deterministicWallets.rollbackCreatedWallets(
        preparedWallets,
      );
      result.fold<void>((_) {}, (_) {});
    } catch (_) {
      // The caller still receives the original failure; cleanup is best effort.
    }
  }

  LightningAddressException _mapDeterministicWalletFailure(
    DeterministicWalletFailure failure,
  ) {
    return switch (failure) {
      DeterministicWalletDerivationFailure() ||
      DeterministicWalletStorageFailure() ||
      DeterministicWalletOperationFailure() ||
      DeterministicWalletUnexpectedFailure() =>
        const LightningAddressException.localPreparationFailed(
          code: 'DeterministicWalletPreparationFailed',
          retryable: true,
        ),
      InvalidDeterministicWalletRequestFailure() ||
      DeterministicWalletMismatchFailure() ||
      DeterministicWalletDerivationConflictFailure() ||
      DeterministicWalletRollbackFailure() =>
        const LightningAddressException.unexpected(),
    };
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
      KeychainManifestExceptionType.duplicate => false,
    };
  }
}
