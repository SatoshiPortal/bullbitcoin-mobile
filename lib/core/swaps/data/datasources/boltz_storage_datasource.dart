import 'dart:convert';

import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/swaps/data/models/swap_model.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:boltz/boltz.dart';
import 'package:flutter/material.dart';

class BoltzStorageDatasource {
  final KeyValueStorageDatasource<String> _localSwapStorage;
  final KeyValueStorageDatasource _secureSwapStorage;

  BoltzStorageDatasource({
    required KeyValueStorageDatasource<String> localSwapStorage,
    required KeyValueStorageDatasource<String> secureSwapStorage,
  }) : _localSwapStorage = localSwapStorage,
       _secureSwapStorage = secureSwapStorage;

  // LOCAL STORAGE
  Future<void> store(SwapModel swap) async {
    final swapJsonMap = swap.toJson();
    final jsonString = jsonEncode(swapJsonMap);
    await _localSwapStorage.saveValue(key: swap.id, value: jsonString);
  }

  Future<SwapModel?> fetch(String swapId) async {
    final jsonString = await _localSwapStorage.getValue(swapId);
    if (jsonString == null) {
      return null;
    }
    final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
    return SwapModel.fromJson(jsonMap);
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

  Future<List<SwapModel>> fetchAll() async {
    final allEntries = await _localSwapStorage.getAll();
    final swaps = <SwapModel>[];
    for (final jsonString in allEntries.values) {
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final swap = SwapModel.fromJson(jsonMap);
      swaps.add(swap);
    }
    return swaps;
  }

  Future<void> trash(String swapId) async {
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
      debugPrint('Error getting LbtcLnSwap: $e');
      throw 'Error parsing LbtcLnSwap: $e';
    }
  }

  Future<ChainSwap> fetchChainSwap(String swapId) async {
    final key = '${SecureStorageKeyPrefixConstants.swap}$swapId';
    final jsonSwap = await _secureSwapStorage.getValue(key) as String;
    return ChainSwap.fromJson(jsonStr: jsonSwap);
  }
}
