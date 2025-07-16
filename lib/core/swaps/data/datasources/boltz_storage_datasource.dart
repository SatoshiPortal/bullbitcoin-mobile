import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/data/models/auto_swap_model.dart';
import 'package:bb_mobile/core/swaps/data/models/swap_model.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:boltz/boltz.dart';
import 'package:drift/drift.dart';

class BoltzStorageDatasource {
  final SqliteDatabase _localSwapStorage;
  final KeyValueStorageDatasource _secureSwapStorage;

  BoltzStorageDatasource({
    required SqliteDatabase localSwapStorage,
    required KeyValueStorageDatasource<String> secureSwapStorage,
  }) : _localSwapStorage = localSwapStorage,
       _secureSwapStorage = secureSwapStorage;

  // AUTO SWAP SETTINGS
  Future<void> storeAutoSwapSettings(AutoSwapModel settings) async {
    await _localSwapStorage
        .into(_localSwapStorage.autoSwap)
        .insertOnConflictUpdate(
          AutoSwapCompanion.insert(
            id: const Value(1),
            enabled: Value(settings.enabled),
            balanceThresholdSats: settings.balanceThresholdSats,
            feeThresholdPercent: settings.feeThresholdPercent,
            blockTillNextExecution: Value(settings.blockTillNextExecution),
            alwaysBlock: Value(settings.alwaysBlock),
          ),
        );
  }

  Future<AutoSwapModel> getAutoSwapSettings() async {
    final settings =
        await (_localSwapStorage.select(_localSwapStorage.autoSwap)
          ..where((tbl) => tbl.id.equals(1))).getSingle();
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
            feeThresholdPercent: settings.feeThresholdPercent,
            blockTillNextExecution: Value(settings.blockTillNextExecution),
            alwaysBlock: Value(settings.alwaysBlock),
          ),
        );
  }

  Future<AutoSwapModel> getAutoSwapSettingsTestnet() async {
    final settings =
        await (_localSwapStorage.select(_localSwapStorage.autoSwap)
          ..where((tbl) => tbl.id.equals(2))).getSingle();
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
    final swap =
        await _localSwapStorage.managers.swaps
            .filter((f) => f.id(swapId))
            .getSingleOrNull();
    if (swap == null) return null;
    return SwapModel.fromSqlite(swap);
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
    final all =
        await _localSwapStorage.managers.swaps.filter((f) {
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
    final swap =
        await _localSwapStorage.managers.swaps
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
      log.severe('Error getting LbtcLnSwap: $e');
      throw 'Error parsing LbtcLnSwap: $e';
    }
  }

  Future<ChainSwap> fetchChainSwap(String swapId) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}$swapId';
    final jsonSwap = await _secureSwapStorage.getValue(key) as String;
    return ChainSwap.fromJson(jsonStr: jsonSwap);
  }
}
