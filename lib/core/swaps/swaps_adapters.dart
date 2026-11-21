import 'package:preferences/preferences.dart' as settings;
import 'package:electrum/electrum.dart';
import 'package:electrum/setup.dart';
import 'package:bb_mobile/features/swap/domain/swap_network_policy.dart';
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/features/send/data/broadcast_failure_mapper.dart';
import 'package:bb_mobile/features/send/domain/broadcast_failure.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:swaps/swaps.dart' as swaps;
import 'package:bull_logger/bull_logger.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart';

/// Opens the engine's own database file. Same platform choices as the app
/// database (documents dir, WAL, busy timeout, cross-isolate sharing) — the
/// engine receives the configured executor from composition.
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

/// The app's electrum selection/fallback seam, unchanged: custom-if-set else
/// defaults, never mixing tiers.
class AppElectrumRunner implements swaps.ElectrumRunner {
  final ElectrumServersPort _port;

  AppElectrumRunner(this._port);

  @override
  Future<T> run<T>({
    required bool isLiquid,
    required NetworkEnv environment,
    required Future<T> Function(swaps.ElectrumConnection connection) operation,
    bool Function(Object error)? isTransient,
  }) => _port.runWithFallback(
    network: _network(isLiquid: isLiquid, environment: environment),
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
    required NetworkEnv environment,
  }) async {
    try {
      return await _port.hasCustomServers(
        network: _network(isLiquid: isLiquid, environment: environment),
      );
    } on Exception {
      return true;
    }
  }

  ElectrumServerNetwork _network({
    required bool isLiquid,
    required NetworkEnv environment,
  }) => ElectrumServerNetwork.fromNetworkEnv(environment, isLiquid: isLiquid);
}

/// The user's own Electrum servers settling a lockup whose broadcast outcome
/// is unknown: the same custom-if-set-else-defaults selection as every other
/// wallet call, never a third-party explorer.
class AppLockupChain implements swaps.LockupChain {
  final WalletConnectionPort _connections;
  final Preferences? _settingsRepository;

  AppLockupChain(this._connections, {this._settingsRepository});

  @override
  Future<String?> txidOf({
    required String signedTx,
    required bool isLiquid,
  }) async {
    if (!isLiquid) return bitcoinPsbtTransactionId(signedTx);
    return switch (decodeLiquidPset(signedTx)) {
      Ok(:final value) => value.txid,
      Err() => null,
    };
  }

  @override
  Future<bool> isKnown({
    required String txid,
    required String signedTx,
    required bool isLiquid,
    required NetworkEnv environment,
  }) async {
    final result = await _connections.run(
      network: _network(isLiquid: isLiquid, environment: environment),
      operation: (connection) => isLiquid
          ? liquidTransactionKnown(txid, connection)
          : bitcoinTransactionKnown(txid, connection),
      mayRetry: (failure) => failure is SyncConnectionFailure,
    );
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw swaps.SwapsException(
        'lockup lookup failed: ${failure.logCode}',
      ),
    };
  }

  @override
  Future<swaps.LockupBroadcast> broadcast({
    required String signedTx,
    required bool isLiquid,
    required NetworkEnv environment,
    void Function()? requireAdmission,
  }) async {
    if (environment != NetworkEnv.mainnet) {
      final repository = _settingsRepository;
      if (repository == null) throw const swaps.SwapsAuthorizationFailure();
      try {
        final settings = (await repository.fetch()).fold(
          (value) => value,
          (failure) => throw Exception('Preferences read failed'),
        );
        if (settings.isSuperuser != true || settings.isDevModeEnabled != true) {
          throw const swaps.SwapsAuthorizationFailure();
        }
      } catch (_) {
        throw const swaps.SwapsAuthorizationFailure();
      }
    }
    requireAdmission?.call();
    final Result<String, SyncFailure> result;
    if (isLiquid) {
      result = await broadcastLiquidTransaction(
        signedTx,
        network: LiquidNetwork.fromName(environment.name),
        connections: _connections,
      );
    } else {
      final List<int> transaction;
      try {
        transaction = decodeBitcoinPsbt(signedTx).bytes;
      } on FormatException {
        return const swaps.LockupRejected();
      }
      result = await broadcastBitcoinTransaction(
        transaction,
        network: BitcoinNetwork.fromName(environment.name),
        connections: _connections,
      );
    }
    return switch (result) {
      Ok(:final value) => swaps.LockupAccepted(value),
      Err(:final failure) => switch (broadcastFailureCategory(failure)) {
        BroadcastFailureCategory.rejected => const swaps.LockupRejected(),
        BroadcastFailureCategory.alreadyInChain =>
          const swaps.LockupAlreadyInChain(),
        _ => const swaps.LockupOutcomeUnknown(),
      },
    };
  }

  static Network _network({
    required bool isLiquid,
    required NetworkEnv environment,
  }) => isLiquid
      ? LiquidNetwork.fromName(environment.name)
      : BitcoinNetwork.fromName(environment.name);
}

/// Bundles the app-side callbacks the engine's constructor takes.
class SwapsAppGlue {
  final WalletRepository _walletRepository;
  final Secrets _secrets;

  SwapsAppGlue({required this._walletRepository, required this._secrets});

  Future<List<swaps.SwapWalletInfo>> wallets({
    required NetworkEnv environment,
  }) async {
    if (!swapEnvironmentAvailable(environment)) return [];
    final all = switch (await _walletRepository.getWallets(
      environment: settings.Environment.fromName(environment.name),
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
    required NetworkEnv environment,
  }) async {
    if (!swapEnvironmentAvailable(environment)) {
      return null;
    }
    final defaults = switch (await _walletRepository.getWallets(
      onlyDefaults: true,
      onlyBitcoin: true,
      environment: settings.Environment.fromName(environment.name),
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

    final network = BitcoinNetwork.fromName(environment.name);
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
      environment: environment,
    );
  }
}

/// Thrown when the wallets the engine needs cannot be read or the swap key
/// cannot be derived. The message carries the failure type only.
class SwapsAppGlueException extends BullException {
  SwapsAppGlueException(super.message);
}
