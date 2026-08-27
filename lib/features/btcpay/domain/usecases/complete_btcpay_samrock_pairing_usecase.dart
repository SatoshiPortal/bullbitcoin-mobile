import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/core/deterministic_wallets/deterministic_wallets.dart';
import 'package:bb_mobile/core/deterministic_wallets/prepare_deterministic_wallets_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/apply_wallet_behavior_defaults_usecase.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_connection.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_failure.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_wallet.dart';
import 'package:bb_mobile/features/btcpay/domain/repositories/btcpay_connection_repository.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_request.dart';
import 'package:bb_mobile/features/btcpay/domain/repositories/samrock_pairing_repository.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_setup_payload_builder.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Fingerprint;

class CompleteBtcpaySamRockPairingUsecase {
  final GetSettingsUsecase _getSettings;
  final SamRockPairingRequestParser _parser;
  final PrepareDeterministicWalletsUsecase _prepareWallets;
  final SamRockPairingRepository _pairingService;
  final BtcpayConnectionRepository _connectionRepository;
  final ApplyWalletBehaviorDefaultsUsecase _applyWalletBehaviorDefaults;
  final KeychainManifestFacade _keychainManifest;

  const CompleteBtcpaySamRockPairingUsecase(
    this._getSettings,
    this._parser,
    this._prepareWallets,
    this._pairingService,
    this._connectionRepository,
    this._applyWalletBehaviorDefaults,
    this._keychainManifest,
  );

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
    switch (await _prepareWallets.execute(_btcpayWalletsRequest(environment))) {
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

    final manifestResult = await _recordBtcpayKeychainManifestEntries(
      preparedWallets,
    );
    if (manifestResult case Err(:final failure)) {
      log.warning(
        'Could not record BTCPay recovery metadata before submission',
        error: failure.runtimeType,
      );
      final rollback = await _prepareWallets.rollbackCreatedWallets(
        preparedWallets,
      );
      if (rollback case Err()) return const Err(BtcpayRollbackFailure());
      return failure is KeychainManifestConflictFailure
          ? const Err(BtcpayKeychainConflictFailure())
          : Err(BtcpayLocalSetupFailure(failure.runtimeType.toString()));
    }

    final Map<String, Object?> payload;
    switch (const SamRockSetupPayloadBuilder().build(
      request: request,
      preparedWallets: preparedWallets,
    )) {
      case Ok(:final value):
        payload = value;
      case Err(:final failure):
        log.warning(
          'Could not build the BTCPay payload after recovery metadata was recorded',
          error: failure.runtimeType,
        );
        return Err(BtcpayLocalSetupFailure(failure.runtimeType.toString()));
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

  Future<Result<bool, KeychainManifestFailure>>
  _recordBtcpayKeychainManifestEntries(
    PreparedDeterministicWallets preparedWallets,
  ) {
    final reservation = Bip85Reservations.btcpayWalletSeed;
    final parent = Fingerprint.tryParse(preparedWallets.parentFingerprint);
    final child = Fingerprint.tryParse(preparedWallets.childSeedFingerprint);
    if (parent == null || child == null) {
      return Future.value(const Err(KeychainManifestConflictFailure()));
    }
    return _keychainManifest.recordReservedDerivation(
      reservationId: reservation.id,
      parentFingerprint: parent,
      derivationPath: preparedWallets.derivationPath,
      wallets: preparedWallets.wallets
          .map((prepared) {
            return KeychainManifestWalletBinding(
              walletId: prepared.walletId,
              childSeedFingerprint: child,
              network: prepared.network,
              scriptType: prepared.scriptType,
            );
          })
          .toList(growable: false),
    );
  }

  DeterministicWalletsRequest _btcpayWalletsRequest(Environment environment) {
    final reservation = Bip85Reservations.btcpayWalletSeed;
    return DeterministicWalletsRequest(
      bip85Index: reservation.walletIndex,
      bip85Alias: reservation.deterministicAlias,
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
      final result = await _applyWalletBehaviorDefaults.execute(
        walletId: prepared.walletId,
        hideOnHome: network == BtcpayWalletNetwork.liquid,
        autoSweepEnabled: network == BtcpayWalletNetwork.liquid,
      );
      if (result case Err(:final failure)) {
        log.warning(
          'BTCPay wallet behavior defaults could not be applied',
          error: failure.runtimeType,
        );
      }
    }
  }
}

const _safeUncertainMessage =
    'BTCPay setup was submitted, but completion could not be confirmed';
const _safeLocalSaveMessage =
    'BTCPay setup was submitted, but local pairing state could not be saved';
