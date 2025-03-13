import 'dart:convert';

import 'package:bb_mobile/_core/data/datasources/key_value_storage/key_value_storage_data_source.dart';
import 'package:bb_mobile/_core/data/models/swap_model.dart';
import 'package:bb_mobile/_utils/constants.dart';
import 'package:boltz/boltz.dart';

abstract class BoltzStorageDataSource {
  // Local Storage
  Future<void> store(SwapModel swap);
  Future<SwapModel?> get(String swapId);
  // Type-specific retrieval methods
  Future<LnReceiveSwapModel?> getLnReceiveSwapModel(String swapId);
  Future<LnSendSwapModel?> getLnSendSwapModel(String swapId);
  Future<ChainSwapModel?> getChainSwapModel(String swapId);
  Future<List<SwapModel>> getAll();
  Future<void> delete(String swapId);
  // Secure Storage
  Future<void> storeBtcLnSwap(BtcLnSwap swap);
  Future<void> storeLbtcLnSwap(LbtcLnSwap swap);
  Future<void> storeChainSwap(ChainSwap swap);
  Future<BtcLnSwap> getBtcLnSwap(String swapId);
  Future<LbtcLnSwap> getLbtcLnSwap(String swapId);
  Future<ChainSwap> getChainSwap(String swapId);
  // Future<void> deleteSecureSwap(String swapId);
}

class BoltzStorageDataSourceImpl implements BoltzStorageDataSource {
  final KeyValueStorageDataSource<String> _localSwapStorage;
  final KeyValueStorageDataSource _secureSwapStorage;

  BoltzStorageDataSourceImpl({
    required KeyValueStorageDataSource<String> localSwapStorage,
    required KeyValueStorageDataSource<String> secureSwapStorage,
  })  : _localSwapStorage = localSwapStorage,
        _secureSwapStorage = secureSwapStorage;
  // LOCAL STORAGE
  @override
  Future<void> store(SwapModel swap) async {
    final swapJsonMap = swap.toJson();
    final jsonString = jsonEncode(swapJsonMap);
    await _localSwapStorage.saveValue(key: swap.id, value: jsonString);
  }

  @override
  Future<SwapModel?> get(String swapId) async {
    final jsonString = await _localSwapStorage.getValue(swapId);
    if (jsonString == null) {
      return null;
    }
    final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
    return SwapModel.fromJson(jsonMap);
  }

  @override
  Future<LnReceiveSwapModel?> getLnReceiveSwapModel(String swapId) async {
    final SwapModel? swap = await get(swapId);
    if (swap == null) return null;

    return swap.maybeMap(
      lnReceive: (lnReceiveSwap) => lnReceiveSwap,
      orElse: () => null,
    );
  }

  @override
  Future<LnSendSwapModel?> getLnSendSwapModel(String swapId) async {
    final SwapModel? swap = await get(swapId);
    if (swap == null) return null;

    return swap.maybeMap(
      lnSend: (lnSendSwap) => lnSendSwap,
      orElse: () => null,
    );
  }

  @override
  Future<ChainSwapModel?> getChainSwapModel(String swapId) async {
    final SwapModel? swap = await get(swapId);
    if (swap == null) return null;

    return swap.maybeMap(
      chain: (chainSwap) => chainSwap,
      orElse: () => null,
    );
  }

  @override
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

  @override
  Future<void> delete(String swapId) async {
    await _localSwapStorage.deleteValue(swapId);
  }

  // SECURE STORAGE
  @override
  Future<void> storeBtcLnSwap(BtcLnSwap swap) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}${swap.id}';
    final jsonSwap = await swap.toJson();
    await _secureSwapStorage.saveValue(key: key, value: jsonSwap);
  }

  @override
  Future<void> storeLbtcLnSwap(LbtcLnSwap swap) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}${swap.id}';
    final jsonSwap = await swap.toJson();
    await _secureSwapStorage.saveValue(key: key, value: jsonSwap);
  }

  @override
  Future<void> storeChainSwap(ChainSwap swap) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}${swap.id}';
    final jsonSwap = await swap.toJson();
    await _secureSwapStorage.saveValue(key: key, value: jsonSwap);
  }

  @override
  Future<BtcLnSwap> getBtcLnSwap(String swapId) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}$swapId';
    final jsonSwap = await _secureSwapStorage.getValue(key) as String;
    return BtcLnSwap.fromJson(jsonStr: jsonSwap);
  }

  @override
  Future<LbtcLnSwap> getLbtcLnSwap(String swapId) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}$swapId';
    final jsonSwap = await _secureSwapStorage.getValue(key) as String;
    return LbtcLnSwap.fromJson(jsonStr: jsonSwap);
  }

  @override
  Future<ChainSwap> getChainSwap(String swapId) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}$swapId';
    final jsonSwap = await _secureSwapStorage.getValue(key) as String;
    return ChainSwap.fromJson(jsonStr: jsonSwap);
  }
}
