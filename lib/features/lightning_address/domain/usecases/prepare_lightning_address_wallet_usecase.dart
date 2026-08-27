import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/core/deterministic_wallets/deterministic_wallet_failure.dart';
import 'package:bb_mobile/core/deterministic_wallets/deterministic_wallets.dart';
import 'package:bb_mobile/core/deterministic_wallets/prepare_deterministic_wallets_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/apply_wallet_behavior_defaults_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_failure.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_wallet.dart';
import 'package:primitives/primitives.dart' show Fingerprint;

const _lightningAddressLiquidSpecId = 'lightning-address-liquid';
const _lightningAddressLiquidLabel = 'Lightning Address Liquid';

final class PrepareLightningAddressWalletUsecase {
  final GetSettingsUsecase _getSettings;
  final PrepareDeterministicWalletsUsecase _prepareWallets;
  final KeychainManifestFacade _manifest;
  final ApplyWalletBehaviorDefaultsUsecase _applyDefaults;

  const PrepareLightningAddressWalletUsecase(
    this._getSettings,
    this._prepareWallets,
    this._manifest,
    this._applyDefaults,
  );

  Future<Result<PreparedLightningAddressWallet, LightningAddressFailure>>
  execute({bool recordAsRecovery = false}) async {
    final settings = await _getSettings.execute();
    final preparedResult = await _prepareWallets.execute(
      _request(settings.environment),
    );
    final PreparedDeterministicWallets prepared;
    switch (preparedResult) {
      case Ok(:final value):
        prepared = value;
      case Err(:final failure):
        return Err(_deterministicFailure(failure));
    }

    final manifestResult = await _recordManifest(
      prepared,
      recovered: recordAsRecovery,
    );
    if (manifestResult case Err(:final failure)) {
      final _ = await _prepareWallets.rollbackCreatedWallets(prepared);
      return Err(_manifestFailure(failure));
    }

    final wallet = prepared.wallets.single;
    final defaults = await _applyDefaults.execute(
      walletId: wallet.walletId,
      hideOnHome: true,
      autoSweepEnabled: true,
    );
    if (defaults case Err()) {
      return const Err(
        LightningAddressFailure.operation(
          kind: LightningAddressFailureKind.localPreparation,
          code: 'WalletDefaultsFailed',
          retryable: true,
        ),
      );
    }
    return Ok(
      PreparedLightningAddressWallet(
        walletId: wallet.walletId,
        ctDescriptor: wallet.externalPublicDescriptor,
        created: wallet.created,
      ),
    );
  }

  DeterministicWalletsRequest _request(Environment environment) {
    final reservation = Bip85Reservations.lightningAddressWalletSeed;
    return DeterministicWalletsRequest(
      bip85Index: reservation.walletIndex,
      bip85Alias: reservation.deterministicAlias,
      environment: environment,
      walletSpecs: [
        DeterministicWalletSpec(
          id: _lightningAddressLiquidSpecId,
          network: environment.isMainnet
              ? Network.liquidMainnet
              : Network.liquidTestnet,
          scriptType: ScriptType.bip84,
          label: _lightningAddressLiquidLabel,
          isDefault: false,
          sync: false,
        ),
      ],
    );
  }

  Future<Result<bool, KeychainManifestFailure>> _recordManifest(
    PreparedDeterministicWallets prepared, {
    required bool recovered,
  }) {
    final reservation = Bip85Reservations.lightningAddressWalletSeed;
    final wallet = prepared.wallets.single;
    final parent = Fingerprint.tryParse(prepared.parentFingerprint);
    final child = Fingerprint.tryParse(prepared.childSeedFingerprint);
    if (parent == null || child == null) {
      return Future.value(const Err(KeychainManifestConflictFailure()));
    }
    final bindings = [
      KeychainManifestWalletBinding(
        walletId: wallet.walletId,
        childSeedFingerprint: child,
        network: wallet.network,
        scriptType: wallet.scriptType,
      ),
    ];
    return recovered
        ? _manifest.recordRecoveredDerivation(
            reservationId: reservation.id,
            parentFingerprint: parent,
            derivationPath: prepared.derivationPath,
            wallets: bindings,
          )
        : _manifest.recordReservedDerivation(
            reservationId: reservation.id,
            parentFingerprint: parent,
            derivationPath: prepared.derivationPath,
            wallets: bindings,
          );
  }

  LightningAddressFailure _deterministicFailure(
    DeterministicWalletFailure failure,
  ) => switch (failure) {
    DeterministicWalletDerivationFailure() ||
    DeterministicWalletOperationFailure() =>
      const LightningAddressFailure.operation(
        kind: LightningAddressFailureKind.localPreparation,
        code: 'WalletPreparationFailed',
        retryable: true,
      ),
    InvalidDeterministicWalletRequestFailure() ||
    DeterministicWalletMismatchFailure() ||
    DeterministicWalletDerivationConflictFailure() ||
    DeterministicWalletRollbackFailure() =>
      const LightningAddressFailure.operation(
        kind: LightningAddressFailureKind.unexpected,
        code: 'Unexpected',
        retryable: false,
      ),
  };

  LightningAddressFailure _manifestFailure(KeychainManifestFailure failure) =>
      LightningAddressFailure.operation(
        kind: LightningAddressFailureKind.localPreparation,
        code: 'ManifestRecordFailed',
        retryable:
            failure is KeychainManifestStorageFailure ||
            failure is KeychainManifestSeedFailure,
      );
}
