import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_server_network.dart';
import 'package:bb_mobile/features/swap/domain/swap_network_policy.dart';
import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/blockchain/data/datasources/lwk_liquid_blockchain_datasource.dart';
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:bb_mobile/features/send/data/broadcast_failure_mapper.dart';
import 'package:bb_mobile/features/send/domain/broadcast_failure.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' as wallet;
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:swaps/swaps.dart' as swaps;
import 'package:bull_logger/bull_logger.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:secrets/secrets.dart';

/// Opens the engine's own database file. Same platform choices as the app
/// database (documents dir, WAL, busy timeout, cross-isolate sharing) — the
/// package itself stays pure Dart and just takes the executor.
QueryExecutor openBoltzSwapsDbConnection() {
  return driftDatabase(
    name: swaps.BoltzSwapsDatabase.name,
    native: DriftNativeOptions(
      databaseDirectory: getApplicationDocumentsDirectory,
      shareAcrossIsolates: true,
      setup: (database) {
        database.execute('PRAGMA busy_timeout = 2000;');
        database.execute('PRAGMA journal_mode = WAL;');
        database.execute('PRAGMA synchronous = FULL;');
      },
    ),
  );
}

/// App logger behind the package's silent-by-default log seam.
class AppSwapsLog implements swaps.SwapsLog {
  const AppSwapsLog();

  @override
  void fine(String message) => log.fine(message);
  @override
  void info(String message) => log.info(message);
  @override
  void warning(String message) => log.warning(message);
  @override
  void severe(String message, {Object? error, StackTrace? trace}) {
    log.warning(message);
    log.severe(
      message: 'SWAPS: engine failure',
      error: error?.runtimeType ?? 'swaps',
      trace: trace ?? StackTrace.current,
    );
  }

  @override
  Future<void> flush() => log.flush();
}

/// Platform secure storage behind the engine's secret-store contract.
class SecureSecretStore implements swaps.SecretStore {
  final KeyValueStorageDatasource<String> _secure;

  SecureSecretStore(this._secure);

  @override
  Future<void> write(String key, String value) =>
      _secure.saveValue(key: key, value: value);

  @override
  Future<String?> read(String key) async => _secure.getValue(key);

  @override
  Future<void> delete(String key) => _secure.deleteValue(key);
}

/// The app's electrum selection/fallback seam, unchanged: custom-if-set else
/// defaults, never mixing tiers.
class AppElectrumRunner implements swaps.ElectrumRunner {
  final ElectrumServersPort _port;

  AppElectrumRunner(this._port);

  @override
  Future<T> run<T>({
    required bool isLiquid,
    required bool isTestnet,
    required Future<T> Function(swaps.ElectrumConnection connection) operation,
    bool Function(Object error)? isTransient,
  }) => _port.runWithFallback(
    network: _network(isLiquid: isLiquid, isTestnet: isTestnet),
    isTransient: isTransient,
    operation: (connection) => operation(
      swaps.ElectrumConnection(
        url: connection.url,
        validateDomain: connection.validateDomain,
        timeout: connection.timeout,
      ),
    ),
  );

  @override
  Future<bool> usesCustomServers({
    required bool isLiquid,
    required bool isTestnet,
  }) async {
    try {
      return await _port.hasCustomServers(
        network: _network(isLiquid: isLiquid, isTestnet: isTestnet),
      );
    } on Exception {
      return true;
    }
  }

  ElectrumServerNetwork _network({
    required bool isLiquid,
    required bool isTestnet,
  }) => ElectrumServerNetwork.fromNetworkEnv(
    isTestnet ? NetworkEnv.testnet : NetworkEnv.mainnet,
    isLiquid: isLiquid,
  );
}

/// The user's own Electrum servers settling a lockup whose broadcast outcome
/// is unknown: the same custom-if-set-else-defaults selection as every other
/// wallet call, never a third-party explorer.
class AppLockupChain implements swaps.LockupChain {
  final ElectrumServersPort _port;
  final BdkBitcoinBlockchainDatasource _bitcoin;
  final LwkLiquidBlockchainDatasource _liquid;

  AppLockupChain(this._port, this._bitcoin, this._liquid);

  @override
  Future<String?> txidOf({
    required String signedTx,
    required bool isLiquid,
  }) async {
    if (isLiquid) return null;
    return bdk.Psbt(psbtBase64: signedTx).extractTx().computeTxid().toString();
  }

  @override
  Future<bool> isKnown({
    required String txid,
    required String signedTx,
    required bool isLiquid,
    required bool isTestnet,
  }) async {
    if (!isLiquid) {
      return _port.runWithFallback(
        network: _network(isLiquid: false, isTestnet: isTestnet),
        operation: (connection) =>
            _bitcoin.isTransactionKnown(txid, connection: connection),
      );
    }
    // No Liquid txid can be computed here, so a candidate txid (the node's
    // broadcast reply, or Boltz's event) counts only when the server's bytes
    // under it are exactly our signed lockup.
    final held = await _port.runWithFallback(
      network: _network(isLiquid: true, isTestnet: isTestnet),
      operation: (connection) =>
          _bitcoin.fetchRawTransaction(txid, connection: connection),
    );
    if (held == null) return false;
    final ours = await lwk.extractTxBytes(pset: signedTx);
    return _sameBytes(held, ours);
  }

  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Future<swaps.LockupBroadcast> broadcast({
    required String signedTx,
    required bool isLiquid,
    required bool isTestnet,
  }) async {
    try {
      final txid = await _port.runWithFallback<String>(
        network: _network(isLiquid: isLiquid, isTestnet: isTestnet),
        operation: (connection) => isLiquid
            ? _liquid.broadcastTransaction(
                signedPset: signedTx,
                network: isTestnet
                    ? wallet.Network.liquidTestnet
                    : wallet.Network.liquidMainnet,
                electrumServerUrl: connection.url,
              )
            : _bitcoin.broadcastPsbt(signedTx, connection: connection),
      );
      return swaps.LockupAccepted(txid);
    } catch (e) {
      return switch (mapBroadcastFailure(e)) {
        BroadcastFailureCategory.rejected => const swaps.LockupRejected(),
        BroadcastFailureCategory.alreadyInChain =>
          const swaps.LockupAlreadyInChain(),
        _ => const swaps.LockupOutcomeUnknown(),
      };
    }
  }

  ElectrumServerNetwork _network({
    required bool isLiquid,
    required bool isTestnet,
  }) => ElectrumServerNetwork.fromNetworkEnv(
    isTestnet ? NetworkEnv.testnet : NetworkEnv.mainnet,
    isLiquid: isLiquid,
  );
}

/// Bundles the app-side callbacks the engine's constructor takes.
class SwapsAppGlue {
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;
  final Secrets _secrets;

  SwapsAppGlue({
    required this._walletRepository,
    required this._settingsRepository,
    required this._secrets,
  });

  Future<List<swaps.SwapWalletInfo>> wallets({required bool isTestnet}) async {
    final settings = await _settingsRepository.fetch();
    if (!swapEnvironmentAvailable(settings.environment.networkEnv)) return [];
    final all = switch (await _walletRepository.getWallets(
      environment: settings.environment,
    )) {
      Ok(:final value) => value,
      Err(:final failure) => throw SwapsAppGlueException(
        'wallets read failed: ${failure.runtimeType}',
      ),
    };
    return [
      for (final w in all)
        swaps.SwapWalletInfo(
          id: w.id,
          isLiquid: w.isLiquid,
          isDefault: w.isDefault,
          fingerprint: w.masterFingerprint,
        ),
    ];
  }

  /// The swap master key for the default bitcoin wallet, derived by the
  /// `secrets` package. The wallet's words never leave it; null when there is
  /// no default bitcoin wallet with a mnemonic (watch-only, hardware-only,
  /// pre-onboarding).
  Future<swaps.DerivedSwapMasterKey?> swapMasterKey({
    required bool isTestnet,
  }) async {
    final settings = await _settingsRepository.fetch();
    if (!swapEnvironmentAvailable(settings.environment.networkEnv)) {
      return null;
    }
    final defaults = switch (await _walletRepository.getWallets(
      onlyDefaults: true,
      onlyBitcoin: true,
      environment: settings.environment,
    )) {
      Ok(:final value) => value,
      Err(:final failure) => throw SwapsAppGlueException(
        'default wallets read failed: ${failure.runtimeType}',
      ),
    };
    if (defaults.isEmpty) return null;
    final walletFingerprint = defaults.first.masterFingerprint;
    if (walletFingerprint.isEmpty) return null;

    final secret = switch (await _secrets.fetch(
      Fingerprint(walletFingerprint),
    )) {
      Ok(:final value) => value,
      Err() => null,
    };
    if (secret == null || !secret.info.isMnemonic) return null;

    final network = isTestnet ? BitcoinNetwork.testnet : BitcoinNetwork.mainnet;
    final key = switch (await secret.derive.swapKey(network: network)) {
      Ok(:final value) => value,
      Err(:final failure) => throw SwapsAppGlueException(
        'swap key derivation failed: ${failure.runtimeType}',
      ),
    };
    return swaps.DerivedSwapMasterKey(
      walletFingerprint: walletFingerprint,
      xprv: key.xprv,
      xpub: key.xpub,
      mnemonic: key.mnemonic,
      fingerprint: key.fingerprint.hex,
      isTestnet: key.isTestnet,
    );
  }
}

/// Thrown when the wallets the engine needs cannot be read or the swap key
/// cannot be derived. The message carries the failure type only.
class SwapsAppGlueException extends BullException {
  SwapsAppGlueException(super.message);
}
