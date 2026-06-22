import 'dart:convert';

import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/data/models/auto_swap_model.dart';
import 'package:bb_mobile/core/swaps/data/models/swap_master_key_model.dart';
import 'package:bb_mobile/core/swaps/data/models/swap_model.dart';
import 'package:bb_mobile/core/swaps/domain/entity/boltz_network.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bull_sdk/boltz.dart';
import 'package:drift/drift.dart';

class BoltzStorageDatasource {
  final SqliteDatabase _localSwapStorage;
  final KeyValueStorageDatasource _secureSwapStorage;

  BoltzStorageDatasource({
    required this._localSwapStorage,
    required KeyValueStorageDatasource<String> this._secureSwapStorage,
  });

  // AUTO SWAP SETTINGS
  Future<void> storeAutoSwapSettings(AutoSwapModel settings) async {
    await _localSwapStorage
        .into(_localSwapStorage.autoSwap)
        .insertOnConflictUpdate(
          AutoSwapCompanion.insert(
            id: const Value(1),
            enabled: Value(settings.enabled),
            balanceThresholdSats: settings.balanceThresholdSats,
            triggerBalanceSats: settings.triggerBalanceSats,
            feeThresholdPercent: settings.feeThresholdPercent,
            blockTillNextExecution: Value(settings.blockTillNextExecution),
            alwaysBlock: Value(settings.alwaysBlock),
            recipientWalletId: Value(settings.recipientWalletId),
            showWarning: Value(settings.showWarning),
          ),
        );
  }

  Future<AutoSwapModel> getAutoSwapSettings() async {
    final settings = await (_localSwapStorage.select(
      _localSwapStorage.autoSwap,
    )..where((tbl) => tbl.id.equals(1))).getSingle();
    return AutoSwapModel.fromSqlite(settings);
  }

  Future<void> storeAutoSwapSettingsTestnet(AutoSwapModel settings) async {
    await _localSwapStorage
        .into(_localSwapStorage.autoSwap)
        .insertOnConflictUpdate(
          AutoSwapCompanion.insert(
            id: const Value(2),
            enabled: Value(settings.enabled),
            balanceThresholdSats: settings.balanceThresholdSats,
            triggerBalanceSats: settings.triggerBalanceSats,
            feeThresholdPercent: settings.feeThresholdPercent,
            blockTillNextExecution: Value(settings.blockTillNextExecution),
            alwaysBlock: Value(settings.alwaysBlock),
            recipientWalletId: Value(settings.recipientWalletId),
            showWarning: Value(settings.showWarning),
          ),
        );
  }

  Future<AutoSwapModel> getAutoSwapSettingsTestnet() async {
    final settings = await (_localSwapStorage.select(
      _localSwapStorage.autoSwap,
    )..where((tbl) => tbl.id.equals(2))).getSingle();
    return AutoSwapModel.fromSqlite(settings);
  }

  // LOCAL STORAGE
  Future<void> store(SwapModel swap) async {
    final row = swap.toSqlite();
    await _localSwapStorage
        .into(_localSwapStorage.swaps)
        .insertOnConflictUpdate(row);
  }

  Future<SwapModel?> fetch(String swapId) async {
    final swap = await _localSwapStorage.managers.swaps
        .filter((f) => f.id(swapId))
        .getSingleOrNull();
    if (swap == null) return null;
    return SwapModel.fromSqlite(swap);
  }

  Stream<SwapModel> watchSwap(String swapId) {
    return _localSwapStorage.managers.swaps
        .filter((f) => f.id(swapId))
        .watchSingleOrNull()
        .where((row) => row != null)
        .map((row) => SwapModel.fromSqlite(row!));
  }

  Future<LnReceiveSwapModel?> fetchLnReceiveSwapModel(String swapId) async {
    final SwapModel? swap = await fetch(swapId);
    if (swap == null) return null;

    return switch (swap) {
      LnReceiveSwapModel() => swap,
      _ => null,
    };
  }

  Future<LnSendSwapModel?> fetchLnSendSwapModel(String swapId) async {
    final SwapModel? swap = await fetch(swapId);
    if (swap == null) return null;

    return switch (swap) {
      LnSendSwapModel() => swap,
      _ => null,
    };
  }

  Future<ChainSwapModel?> fetchChainSwapModel(String swapId) async {
    final SwapModel? swap = await fetch(swapId);
    if (swap == null) return null;

    return switch (swap) {
      ChainSwapModel() => swap,
      _ => null,
    };
  }

  Future<List<SwapModel>> fetchAll({String? walletId, bool? isTestnet}) async {
    final all = await _localSwapStorage.managers.swaps.filter((f) {
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
    return all.map((e) => SwapModel.fromSqlite(e)).toList();
  }

  Future<SwapModel?> fetchByTxId(String txId) async {
    final swap = await _localSwapStorage.managers.swaps
        .filter(
          (f) =>
              f.sendTxid.equals(txId) |
              f.receiveTxid.equals(txId) |
              f.refundTxid.equals(txId),
        )
        .getSingleOrNull();
    if (swap == null) return null;
    return SwapModel.fromSqlite(swap);
  }

  Future<void> trash(String swapId) async {
    await _localSwapStorage.managers.swaps.filter((f) => f.id(swapId)).delete();
  }

  Future<void> deleteFromSecureStorage(String swapId) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}$swapId';
    try {
      await _secureSwapStorage.deleteValue(key);
    } catch (e) {
      log.fine('Error deleting swap from secure storage: $e');
    }
  }

  // SECURE STORAGE — SWAP MASTER KEY
  //
  // Keyed per network AND the default wallet's seed fingerprint, never by
  // network alone: the fingerprint guarantees a different default wallet (or a
  // stale key the iOS keychain kept after the app was deleted) can never be
  // read for the current wallet — we'd only ever read the swap mnemonic that
  // belongs to the current default seed.
  String _swapMasterKeyStorageKey(BoltzNetwork network, String fingerprint) =>
      '${SecureStorageKeyPrefixConstants.swapMasterKey}'
      '${network.value}_$fingerprint';

  Future<void> storeSwapMasterKey(
    SwapMasterKeyModel swapMasterKey, {
    required String walletFingerprint,
  }) async {
    final key = _swapMasterKeyStorageKey(
      swapMasterKey.boltzNetwork,
      walletFingerprint,
    );
    await _secureSwapStorage.saveValue(
      key: key,
      value: jsonEncode(swapMasterKey.toJson()),
    );
  }

  Future<bool> swapMasterKeyExists(
    BoltzNetwork network, {
    required String walletFingerprint,
  }) async {
    try {
      final value = await _secureSwapStorage.getValue(
        _swapMasterKeyStorageKey(network, walletFingerprint),
      );
      return value != null;
    } catch (_) {
      return false;
    }
  }

  Future<SwapMasterKeyModel> fetchSwapMasterKey(
    BoltzNetwork network, {
    required String walletFingerprint,
  }) async {
    final jsonString =
        await _secureSwapStorage.getValue(
              _swapMasterKeyStorageKey(network, walletFingerprint),
            )
            as String;
    return SwapMasterKeyModel.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }

  // Global, per-network swap derivation index (under the swap master key).
  // null when never set, so callers can initialise it.
  Future<int?> getSwapKeyIndex(BoltzNetwork network) async {
    try {
      final key =
          '${SecureStorageKeyPrefixConstants.swapKeyIndex}${network.value}';
      final value = await _secureSwapStorage.getValue(key);
      if (value == null) return null;
      return int.tryParse(value as String);
    } catch (_) {
      return null;
    }
  }

  Future<void> setSwapKeyIndex(BoltzNetwork network, int index) async {
    final key =
        '${SecureStorageKeyPrefixConstants.swapKeyIndex}${network.value}';
    await _secureSwapStorage.saveValue(key: key, value: index.toString());
  }

  // SECURE STORAGE
  Future<void> storeBtcLnSwap(BtcLnSwap swap) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}${swap.id}';
    final jsonSwap = await swap.toJson();
    await _secureSwapStorage.saveValue(key: key, value: jsonSwap);
  }

  Future<void> storeLbtcLnSwap(LbtcLnSwap swap) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}${swap.id}';
    final jsonSwap = await swap.toJson();
    await _secureSwapStorage.saveValue(key: key, value: jsonSwap);
  }

  Future<void> storeChainSwap(ChainSwap swap) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}${swap.id}';
    final jsonSwap = await swap.toJson();
    await _secureSwapStorage.saveValue(key: key, value: jsonSwap);
  }

  Future<BtcLnSwap> fetchBtcLnSwap(String swapId) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}$swapId';
    final jsonSwap = await _secureSwapStorage.getValue(key) as String;
    return BtcLnSwap.fromJson(jsonStr: jsonSwap);
  }

  Future<LbtcLnSwap> fetchLbtcLnSwap(String swapId) async {
    try {
      final key = '${SecureStorageKeyPrefixConstants.swap}$swapId';
      final jsonSwap = await _secureSwapStorage.getValue(key) as String;
      final lbtcLnSwap = await LbtcLnSwap.fromJson(jsonStr: jsonSwap);
      return lbtcLnSwap;
    } catch (e) {
      log.severe(
        message: 'Error getting LbtcLnSwap',
        error: e,
        trace: StackTrace.current,
      );
      throw 'Error parsing LbtcLnSwap: $e';
    }
  }

  Future<ChainSwap> fetchChainSwap(String swapId) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}$swapId';
    final jsonSwap = await _secureSwapStorage.getValue(key) as String;

    return ChainSwap.fromJson(jsonStr: jsonSwap);
  }
}
