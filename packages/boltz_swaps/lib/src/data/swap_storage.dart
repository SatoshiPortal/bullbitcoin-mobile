import 'dart:convert';

import 'package:bull_sdk/boltz.dart';
import 'package:boltz_swaps/src/data/models/boltz_network.dart';
import 'package:boltz_swaps/src/log.dart';

import 'package:boltz_swaps/src/data/models/swap_master_key_model.dart';
import 'package:boltz_swaps/src/data/models/swap_model.dart';
import 'package:boltz_swaps/src/util.dart';
import 'package:synchronized/synchronized.dart';

/// Key prefixes are wire format for existing installs — they must never
/// change. `swapKeyIndex` deliberately differs from the historical
/// `swap_key_index_` (that counter was seeded high by a since-removed bug).
class _Keys {
  static const swap = 'swap_';
  static const swapMasterKey = 'swap_master_key_';
  static const swapKeyIndex = 'swap_master_key_index_';
}

/// Row persistence for swap models: the app implements this over its own
/// database as a dumb row mapper; the engine never touches the database.
abstract class SwapRowStore {
  Future<void> store(SwapModel swapModel);
  Future<SwapModel?> fetch(String swapId);
  Stream<SwapModel> watch(String swapId);
  Future<List<SwapModel>> fetchAll({String? walletId, bool? isTestnet});
  Future<SwapModel?> fetchByTxId(String txId);
  Future<void> trash(String swapId);
}

/// String key-value persistence for swap SECRETS (bull_sdk swap blobs with
/// key material, the swap master key, the key-index counter). Backed by
/// platform secure storage; values must never reach logs or any
/// cloud-synced store.
abstract class SecretStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

/// All swap persistence behind the two dumb app-provided stores above.
class SwapStorage {
  final SwapRowStore _rows;
  final SecretStore _secrets;
  final Map<String, Lock> _writeLocks = {};

  SwapStorage({required this._rows, required this._secrets});

  /// Serializes a fetch→merge→store critical section per swap, so the event
  /// pipeline and a repository writer can never interleave and drop each
  /// other's fields. Non-reentrant: [write] must not call [mutate] for the
  /// same swap.
  Future<T> mutate<T>(String swapId, Future<T> Function() write) =>
      (_writeLocks[swapId] ??= Lock()).synchronized(write);

  // LOCAL ROWS
  Future<void> store(SwapModel swap) => _rows.store(swap);

  Future<SwapModel?> fetch(String swapId) => _rows.fetch(swapId);

  Stream<SwapModel> watchSwap(String swapId) => _rows.watch(swapId);

  Future<LnReceiveSwapModel?> fetchLnReceiveSwapModel(String swapId) async {
    final swap = await fetch(swapId);
    return switch (swap) {
      LnReceiveSwapModel() => swap,
      _ => null,
    };
  }

  Future<LnSendSwapModel?> fetchLnSendSwapModel(String swapId) async {
    final swap = await fetch(swapId);
    return switch (swap) {
      LnSendSwapModel() => swap,
      _ => null,
    };
  }

  Future<ChainSwapModel?> fetchChainSwapModel(String swapId) async {
    final swap = await fetch(swapId);
    return switch (swap) {
      ChainSwapModel() => swap,
      _ => null,
    };
  }

  Future<List<SwapModel>> fetchAll({String? walletId, bool? isTestnet}) =>
      _rows.fetchAll(walletId: walletId, isTestnet: isTestnet);

  Future<SwapModel?> fetchByTxId(String txId) => _rows.fetchByTxId(txId);

  Future<void> trash(String swapId) => _rows.trash(swapId);

  Future<void> deleteFromSecureStorage(String swapId) async {
    try {
      await _secrets.delete('${_Keys.swap}$swapId');
    } catch (e) {
      swapsLog.fine('Error deleting swap from secure storage: $e');
    }
  }

  // SECURE STORAGE — SWAP MASTER KEY
  //
  // Keyed per network AND the default wallet's seed fingerprint, never by a
  // network alone: the fingerprint guarantees a different default wallet (or
  // a stale key the iOS keychain kept after the app was deleted) can never
  // be read for the current wallet.
  String _swapMasterKeyStorageKey(BoltzNetwork network, String fingerprint) =>
      '${_Keys.swapMasterKey}${network.value}_$fingerprint';

  Future<void> storeSwapMasterKey(
    SwapMasterKeyModel swapMasterKey, {
    required String walletFingerprint,
  }) async {
    final key = _swapMasterKeyStorageKey(
      swapMasterKey.boltzNetwork,
      walletFingerprint,
    );
    await _secrets.write(key, jsonEncode(swapMasterKey.toJson()));
  }

  Future<bool> swapMasterKeyExists(
    BoltzNetwork network, {
    required String walletFingerprint,
  }) async {
    try {
      final value = await _secrets.read(
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
    final jsonString = await _secrets.read(
      _swapMasterKeyStorageKey(network, walletFingerprint),
    );
    if (jsonString == null) {
      throw SwapsException(
        'no swap master key in secure storage for wallet $walletFingerprint '
        'on ${network.value}',
      );
    }
    return SwapMasterKeyModel.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }

  /// Deletes the swap master key blob for [walletFingerprint] and,
  /// best-effort, its index counter (keyed by the swap master key's OWN
  /// fingerprint) so a re-derive starts from a clean index.
  Future<void> deleteSwapMasterKey(
    BoltzNetwork network, {
    required String walletFingerprint,
  }) async {
    try {
      final existing = await fetchSwapMasterKey(
        network,
        walletFingerprint: walletFingerprint,
      );
      await _secrets.delete('${_Keys.swapKeyIndex}${existing.fingerprint}');
    } catch (_) {
      // No stored key (or unreadable) — nothing to clean beyond the blob.
    }
    await _secrets.delete(_swapMasterKeyStorageKey(network, walletFingerprint));
  }

  // Keyed by the swap master key's fingerprint, not the network: the swap
  // key material is network-independent, so a per-network counter would
  // reuse child keys.
  Future<int?> getSwapKeyIndex(String swapMasterKeyFingerprint) async {
    try {
      final value = await _secrets.read(
        '${_Keys.swapKeyIndex}$swapMasterKeyFingerprint',
      );
      if (value == null) return null;
      return int.tryParse(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> setSwapKeyIndex(
    String swapMasterKeyFingerprint,
    int index,
  ) async {
    await _secrets.write(
      '${_Keys.swapKeyIndex}$swapMasterKeyFingerprint',
      index.toString(),
    );
  }

  // SECURE STORAGE — BULL_SDK SWAP OBJECTS
  Future<void> storeBtcLnSwap(BtcLnSwap swap) async {
    await _secrets.write('${_Keys.swap}${swap.id}', await swap.toJson());
  }

  Future<void> storeLbtcLnSwap(LbtcLnSwap swap) async {
    await _secrets.write('${_Keys.swap}${swap.id}', await swap.toJson());
  }

  Future<void> storeChainSwap(ChainSwap swap) async {
    await _secrets.write('${_Keys.swap}${swap.id}', await swap.toJson());
  }

  Future<String> _readSwapBlob(String swapId) async {
    final jsonSwap = await _secrets.read('${_Keys.swap}$swapId');
    if (jsonSwap == null) {
      throw SwapsException(
        'no secure-storage blob for swap $swapId — the row exists but its '
        'key material is gone (keychain cleared or partial delete)',
      );
    }
    return jsonSwap;
  }

  Future<BtcLnSwap> fetchBtcLnSwap(String swapId) async {
    return BtcLnSwap.fromJson(jsonStr: await _readSwapBlob(swapId));
  }

  Future<LbtcLnSwap> fetchLbtcLnSwap(String swapId) async {
    return LbtcLnSwap.fromJson(jsonStr: await _readSwapBlob(swapId));
  }

  Future<ChainSwap> fetchChainSwap(String swapId) async {
    return ChainSwap.fromJson(jsonStr: await _readSwapBlob(swapId));
  }
}
