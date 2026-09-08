import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/data/swap_model_sqlite.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:drift/drift.dart';
import 'package:swaps/swaps.dart' as swaps;

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
  void severe(String message, {Object? error, StackTrace? trace}) => log.severe(
    message: message,
    error: error ?? message,
    trace: trace ?? StackTrace.current,
  );
  @override
  Future<void> flush() => log.flush();
}

/// Drift-backed row store: the dumb sqlite half of the engine's persistence.
class DriftSwapRowStore implements swaps.SwapRowStore {
  final SqliteDatabase _db;

  DriftSwapRowStore(this._db);

  @override
  Future<void> store(swaps.SwapModel swapModel) async {
    await _db.into(_db.swaps).insertOnConflictUpdate(swapModel.toSqlite());
  }

  @override
  Future<swaps.SwapModel?> fetch(String swapId) async {
    final row = await _db.managers.swaps
        .filter((f) => f.id(swapId))
        .getSingleOrNull();
    if (row == null) return null;
    return SwapModelSqliteMapper.fromSqlite(row);
  }

  @override
  Stream<swaps.SwapModel> watch(String swapId) => _db.managers.swaps
      .filter((f) => f.id(swapId))
      .watchSingleOrNull()
      .where((row) => row != null)
      .map((row) => SwapModelSqliteMapper.fromSqlite(row!));

  @override
  Future<List<swaps.SwapModel>> fetchAll({
    String? walletId,
    bool? isTestnet,
  }) async {
    final all = await _db.managers.swaps.filter((f) {
      Expression<bool> expr = const Constant(true);
      if (walletId != null) {
        expr =
            expr &
            (f.sendWalletId.equals(walletId) |
                f.receiveWalletId.equals(walletId));
      }
      if (isTestnet != null) {
        expr = expr & f.isTestnet.equals(isTestnet);
      }
      return expr;
    }).get();
    return all.map(SwapModelSqliteMapper.fromSqlite).toList();
  }

  @override
  Future<swaps.SwapModel?> fetchByTxId(String txId) async {
    final row = await _db.managers.swaps
        .filter(
          (f) =>
              f.sendTxid.equals(txId) |
              f.receiveTxid.equals(txId) |
              f.refundTxid.equals(txId),
        )
        .getSingleOrNull();
    if (row == null) return null;
    return SwapModelSqliteMapper.fromSqlite(row);
  }

  @override
  Future<void> trash(String swapId) async {
    await _db.managers.swaps.filter((f) => f.id(swapId)).delete();
  }
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
    network: ElectrumServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: isLiquid,
    ),
    isTransient: isTransient,
    operation: (connection) => operation(
      swaps.ElectrumConnection(
        url: connection.url,
        validateDomain: connection.validateDomain,
        timeout: connection.timeout,
      ),
    ),
  );
}

/// Bundles the app-side callbacks the engine's constructor takes.
class SwapsAppGlue {
  final WalletRepository _walletRepository;
  final SeedRepository _seedRepository;
  final SettingsRepository _settingsRepository;

  SwapsAppGlue({
    required this._walletRepository,
    required this._seedRepository,
    required this._settingsRepository,
  });

  Future<List<swaps.SwapWalletInfo>> wallets({required bool isTestnet}) async {
    final settings = await _settingsRepository.fetch();
    final all = await _walletRepository.getWallets(
      environment: settings.environment,
    );
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

  Future<swaps.SwapSeedSource?> masterSeedSource({
    required bool isTestnet,
  }) async {
    final settings = await _settingsRepository.fetch();
    final defaults = await _walletRepository.getWallets(
      onlyDefaults: true,
      onlyBitcoin: true,
      environment: settings.environment,
    );
    if (defaults.isEmpty) return null;
    final fingerprint = defaults.first.masterFingerprint;
    if (fingerprint.isEmpty) return null;
    final seed = await _seedRepository.get(fingerprint);
    if (seed is! MnemonicSeed) return null;
    return swaps.SwapSeedSource(
      mnemonic: seed.mnemonicWords.join(' '),
      fingerprint: fingerprint,
    );
  }
}
