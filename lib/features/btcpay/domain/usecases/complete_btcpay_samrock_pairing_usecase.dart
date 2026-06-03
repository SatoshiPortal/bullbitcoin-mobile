import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/apply_wallet_behavior_defaults_usecase.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_connection.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_failure.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_wallet.dart';
import 'package:bb_mobile/features/btcpay/domain/repositories/btcpay_connection_repository.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_request.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_service_port.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_setup_payload_builder.dart';
import 'package:bb_mobile/features/deterministic_wallets/public/deterministic_wallets_facade.dart';
import 'package:meta/meta.dart';

class CompleteBtcpaySamRockPairingUsecase {
  final GetSettingsUsecase _getSettings;
  final SamRockPairingRequestParser _parser;
  final DeterministicWalletsFacade _deterministicWallets;
  final SamRockPairingServicePort _pairingService;
  final BtcpayConnectionRepository _connectionRepository;
  final Bip85RegistryFacade _bip85Registry;
  final ApplyWalletBehaviorDefaultsUsecase _applyWalletBehaviorDefaults;

  const CompleteBtcpaySamRockPairingUsecase({
    required this._getSettings,
    required this._parser,
    required this._deterministicWallets,
    required this._pairingService,
    required this._connectionRepository,
    required this._bip85Registry,
    required this._applyWalletBehaviorDefaults,
  });

  @useResult
  Future<Result<BtcpayConnection, BtcpayFailure>> execute({
    required String pairingUrl,
  }) async {
    final SamRockPairingRequest request;
    switch (_parser.parse(pairingUrl)) {
      case Ok(:final value):
        request = value;
      case Err(:final failure):
        return Err(failure);
    }

    final Environment environment;
    try {
      environment = (await _getSettings.execute()).environment;
    } on Exception catch (error, trace) {
      log.warning(
        'Could not resolve the environment for BTCPay pairing',
        error: error.runtimeType,
        trace: trace,
      );
      return Err(BtcpayUnexpectedFailure(error.runtimeType.toString()));
    }

    final PreparedDeterministicWallets preparedWallets;
    switch (await _deterministicWallets.prepare(
      _btcpayWalletsRequest(environment),
    )) {
      case Ok(:final value):
        preparedWallets = value;
      case Err(:final failure):
        log.warning(
          'Could not prepare deterministic BTCPay wallets',
          error: failure.runtimeType,
        );
        return Err(
          BtcpayWalletPreparationFailure(failure.runtimeType.toString()),
        );
    }

    final Map<String, Object?> payload;
    switch (const SamRockSetupPayloadBuilder().build(
      request: request,
      preparedWallets: preparedWallets,
    )) {
      case Ok(:final value):
        payload = value;
      case Err(:final failure):
        final rollbackFailure = await _rollbackPreparedWallets(preparedWallets);
        return Err(rollbackFailure ?? failure);
    }

    final submittedConnection = BtcpayConnection.fromPairing(
      environment: environment,
      request: request,
      walletNetworks: _walletNetworks(preparedWallets),
      walletIds: _walletIds(preparedWallets),
      status: BtcpayConnectionStatus.uncertain,
      updatedAt: DateTime.now().toUtc(),
    );

    final submission = await _pairingService.submitSetup(
      request: request,
      payload: payload,
    );
    if (submission case Err(:final failure)) {
      if (failure is BtcpayPairingRejectedFailure) {
        // Submission was explicitly rejected. Prepared wallets are retained so
        // a later pairing attempt can reuse them without re-derivation.
        return Err(failure);
      }

      log.warning(
        'BTCPay setup submission completion is uncertain',
        error: failure.runtimeType,
      );
      await _saveUncertainBestEffort(
        submittedConnection.copyWith(
          updatedAt: DateTime.now().toUtc(),
          lastError: _safeUncertainMessage,
        ),
      );
      return const Err(BtcpayPairingUncertainFailure());
    }

    await _applyBtcpayWalletBehaviorDefaults(preparedWallets);

    final pairedAt = DateTime.now().toUtc();
    final connection = BtcpayConnection.fromPairing(
      environment: environment,
      request: request,
      walletNetworks: _walletNetworks(preparedWallets),
      walletIds: _walletIds(preparedWallets),
      status: BtcpayConnectionStatus.paired,
      pairedAt: pairedAt,
      updatedAt: pairedAt,
    );
    final saveResult = await _connectionRepository.saveConnection(connection);
    if (saveResult case Err(:final failure)) {
      log.warning(
        'BTCPay setup succeeded but local pairing state could not be saved',
        error: failure.runtimeType,
      );
      await _saveUncertainBestEffort(
        submittedConnection.copyWith(
          updatedAt: DateTime.now().toUtc(),
          lastError: _safeLocalSaveMessage,
        ),
      );
      return const Err(BtcpayPairingUncertainFailure());
    }

    return Ok(connection);
  }

  Future<void> _saveUncertainBestEffort(BtcpayConnection connection) async {
    final result = await _connectionRepository.saveConnection(
      connection.copyWith(status: BtcpayConnectionStatus.uncertain),
    );
    if (result case Err(:final failure)) {
      log.warning(
        'BTCPay pairing uncertainty state could not be saved',
        error: failure.runtimeType,
      );
    }
  }

  Future<BtcpayFailure?> _rollbackPreparedWallets(
    PreparedDeterministicWallets preparedWallets,
  ) async {
    final result = await _deterministicWallets.rollbackCreatedWallets(
      preparedWallets,
    );
    return switch (result) {
      Ok() => null,
      Err(:final failure) => () {
        log.warning(
          'BTCPay pre-submission wallet rollback failed',
          error: failure.runtimeType,
        );
        return BtcpayRollbackFailure(failure.runtimeType.toString());
      }(),
    };
  }

  Future<KeychainManifestRecordReservedDerivationResult>
  _recordBtcpayKeychainManifestEntries(
    PreparedDeterministicWallets preparedWallets,
  ) async {
    return _keychainManifest.recordReservedDerivation(
      _btcpayKeychainManifestRequest(preparedWallets),
    );
  }

  Future<void> _deleteBtcpayKeychainManifestEntriesBestEffort(
    KeychainManifestRecordReservedDerivationResult recordedEntries,
  ) async {
    if (recordedEntries.insertedMaterializations.isEmpty) return;
    try {
      await _keychainManifest.deleteInsertedMaterializations(recordedEntries);
    } catch (e, stack) {
      log.warning(
        'BTCPay rejected setup and keychain manifest cleanup failed',
        error: e,
        trace: stack,
      );
    }
  }

  KeychainManifestReservedDerivationRequest _btcpayKeychainManifestRequest(
    PreparedDeterministicWallets preparedWallets,
  ) {
    final reservation = _bip85Registry.btcpayWalletSeed;
    return KeychainManifestReservedDerivationRequest(
      reservationId: reservation.id,
      parentFingerprint: preparedWallets.parentFingerprint,
      materializations: preparedWallets.wallets
          .map((prepared) {
            final network = BtcpayWalletNetwork.fromSpecId(prepared.specId);
            return KeychainManifestWalletMaterializationRequest(
              walletId: prepared.walletId,
              childSeedFingerprint: preparedWallets.childSeedFingerprint,
              network: prepared.network,
              walletPurpose: network.name,
              scriptType: prepared.scriptType,
            );
          })
          .toList(growable: false),
    );
  }

  DeterministicWalletsRequest _btcpayWalletsRequest(Environment environment) {
    final reservation = _bip85Registry.btcpayWalletSeed;
    return DeterministicWalletsRequest(
      bip85Index: reservation.walletIndex,
      bip85Alias: BtcpayWalletConstants.bip85Alias,
      environment: environment,
      walletSpecs: BtcpayWalletNetwork.values
          .map((network) {
            return DeterministicWalletSpec(
              id: network.specId,
              network: network.networkForEnvironment(environment),
              scriptType: ScriptType.bip84,
              label: network.walletLabel,
              isDefault: false,
              sync: false,
            );
          })
          .toList(growable: false),
    );
  }

  List<BtcpayWalletNetwork> _walletNetworks(
    PreparedDeterministicWallets preparedWallets,
  ) {
    return preparedWallets.wallets
        .map((wallet) => BtcpayWalletNetwork.tryFromSpecId(wallet.specId))
        .whereType<BtcpayWalletNetwork>()
        .toList(growable: false);
  }

  Map<BtcpayWalletNetwork, String> _walletIds(
    PreparedDeterministicWallets preparedWallets,
  ) {
    final walletIds = <BtcpayWalletNetwork, String>{};
    for (final wallet in preparedWallets.wallets) {
      final network = BtcpayWalletNetwork.tryFromSpecId(wallet.specId);
      if (network != null) walletIds[network] = wallet.walletId;
    }
    return walletIds;
  }

  /// Applies the BTCPay wallet behavior defaults best-effort: the server has
  /// already accepted the descriptors at this point, so a local
  /// defaults-application failure must not degrade a successful pairing.
  Future<void> _applyBtcpayWalletBehaviorDefaults(
    PreparedDeterministicWallets preparedWallets,
  ) async {
    for (final prepared in preparedWallets.wallets) {
      final network = BtcpayWalletNetwork.tryFromSpecId(prepared.specId);
      if (network == null) continue;
      try {
        await _applyWalletBehaviorDefaults.execute(
          walletId: prepared.walletId,
          hideOnHome: network == BtcpayWalletNetwork.liquid,
          autoSweepEnabled: network == BtcpayWalletNetwork.liquid,
        );
      } on Exception catch (error, trace) {
        log.warning(
          'BTCPay wallet behavior defaults could not be applied',
          error: error.runtimeType,
          trace: trace,
        );
      }
    }
  }
}

const _safeUncertainMessage =
    'BTCPay setup was submitted, but completion could not be confirmed';
const _safeLocalSaveMessage =
    'BTCPay setup was submitted, but local pairing state could not be saved';
