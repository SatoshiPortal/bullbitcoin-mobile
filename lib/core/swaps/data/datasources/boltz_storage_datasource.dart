import 'dart:convert';

import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/swaps/data/models/swap_model.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:boltz/boltz.dart';

class BoltzStorageDatasource {
  final KeyValueStorageDatasource<String> _localSwapStorage;
  final KeyValueStorageDatasource _secureSwapStorage;

  BoltzStorageDatasource({
    required KeyValueStorageDatasource<String> localSwapStorage,
    required KeyValueStorageDatasource<String> secureSwapStorage,
  })  : _localSwapStorage = localSwapStorage,
        _secureSwapStorage = secureSwapStorage;

  // LOCAL STORAGE
  Future<void> store(SwapModel swap) async {
    final swapJsonMap = swap.toJson();
    final jsonString = jsonEncode(swapJsonMap);
    await _localSwapStorage.saveValue(key: swap.id, value: jsonString);
  }

  Future<SwapModel?> get(String swapId) async {
    final jsonString = await _localSwapStorage.getValue(swapId);
    if (jsonString == null) {
      return null;
    }
    final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
    return SwapModel.fromJson(jsonMap);
  }

  Future<LnReceiveSwapModel?> getLnReceiveSwapModel(String swapId) async {
    final SwapModel? swap = await get(swapId);
    if (swap == null) return null;

    return swap.maybeMap(
      lnReceive: (lnReceiveSwap) => lnReceiveSwap,
      orElse: () => null,
    );
  }

  Future<LnSendSwapModel?> getLnSendSwapModel(String swapId) async {
    final SwapModel? swap = await get(swapId);
    if (swap == null) return null;

    return swap.maybeMap(
      lnSend: (lnSendSwap) => lnSendSwap,
      orElse: () => null,
    );
  }

  Future<ChainSwapModel?> getChainSwapModel(String swapId) async {
    final SwapModel? swap = await get(swapId);
    if (swap == null) return null;

    return swap.maybeMap(
      chain: (chainSwap) => chainSwap,
      orElse: () => null,
    );
  }

  Future<List<SwapModel>> getAll() async {
    final allEntries = await _localSwapStorage.getAll();
    final swaps = <SwapModel>[];
    for (final jsonString in allEntries.values) {
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final swap = SwapModel.fromJson(jsonMap);
      swaps.add(swap);
    }
    return swaps;
  }

  Future<void> delete(String swapId) async {
    await _localSwapStorage.deleteValue(swapId);
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

  Future<BtcLnSwap> getBtcLnSwap(String swapId) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}$swapId';
    final jsonSwap = await _secureSwapStorage.getValue(key) as String;
    return BtcLnSwap.fromJson(jsonStr: jsonSwap);
  }

  Future<LbtcLnSwap> getLbtcLnSwap(String swapId) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}$swapId';
    final jsonSwap = await _secureSwapStorage.getValue(key) as String;
    return LbtcLnSwap.fromJson(jsonStr: jsonSwap);
  }

  Future<ChainSwap> getChainSwap(String swapId) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}$swapId';
    final jsonSwap = await _secureSwapStorage.getValue(key) as String;
    return ChainSwap.fromJson(jsonStr: jsonSwap);
  }
}
