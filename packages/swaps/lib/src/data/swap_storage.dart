import 'dart:convert';

import 'package:secrets/secrets.dart';
import 'package:primitives/primitives.dart';

import 'package:rust_bindings/boltz.dart';
import 'package:swaps/src/data/models/boltz_network.dart';
import 'package:swaps/src/log.dart';

import 'package:swaps/src/data/models/swap_master_key_model.dart';
import 'package:swaps/src/data/models/swap_model.dart';
import 'package:swaps/src/util.dart';
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

/// Owns swap persistence, using the closed keychain capability for secrets.
class SwapStorage {
  final SwapRowStore _rows;
  final SwapKeychain _secrets;
  final Map<String, Lock> _writeLocks = {};
  final Map<String, Lock> _allocationLocks;
  final bool _regtest;

  SwapStorage({required this._rows, required this._secrets})
    : _allocationLocks = {},
      _regtest = false;

  SwapStorage._regtestRows(SwapRowStore rows, SwapStorage canonical)
    : _rows = rows,
      _secrets = canonical._secrets,
      _allocationLocks = canonical._allocationLocks,
      _regtest = true;

  // Preserve the engine's exception-based storage contract. Only failure types
  // leave the custody boundary; a refused read never becomes an absent value.
  T _value<T>(Result<T, SecretFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw Exception(
      'Swap keychain: ${failure.runtimeType}',
    ),
  };

  Future<String?> _readSecret(String key) async =>
      _value(await _secrets.read(key));
  Future<void> _writeSecret(String key, String value) async =>
      _value(await _secrets.write(key, value));
  Future<void> _deleteSecret(String key) async =>
      _value(await _secrets.delete(key));

  /// A row/blob namespace with THE SAME allocation lock and fingerprint counter
  /// as its injected canonical owner. It never creates another allocator map.
  SwapStorage regtestView({required SwapRowStore rows}) =>
      SwapStorage._regtestRows(rows, this);

  bool get isRegtestStore => _regtest;
  String _swapBlobKey(String id) =>
      '${_regtest ? 'swap_regtest_' : _Keys.swap}$id';

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
      await _deleteSecret(_swapBlobKey(swapId));
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
    if (await _readSecret(key) != null) return;
    await _writeSecret(key, jsonEncode(swapMasterKey.toJson()));
  }

  Future<bool> swapMasterKeyExists(
    BoltzNetwork network, {
    required String walletFingerprint,
  }) async {
    final value = await _readSecret(
      _swapMasterKeyStorageKey(network, walletFingerprint),
    );
    return value != null;
  }

  Future<SwapMasterKeyModel> fetchSwapMasterKey(
    BoltzNetwork network, {
    required String walletFingerprint,
  }) async {
    final jsonString = await _readSecret(
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

  /// Deletes the wallet's network-qualified key blob while retaining the
  /// fingerprint high-water index shared by all environments and old creates.
  Future<void> deleteSwapMasterKey(
    BoltzNetwork network, {
    required String walletFingerprint,
  }) => _deleteSecret(_swapMasterKeyStorageKey(network, walletFingerprint));

  // Keyed by the swap master key's fingerprint, not the network: the swap
  // key material is network-independent, so a per-network counter would
  // reuse child keys.
  Future<int?> getSwapKeyIndex(String swapMasterKeyFingerprint) async {
    final value = await _readSecret(
      '${_Keys.swapKeyIndex}$swapMasterKeyFingerprint',
    );
    if (value == null) return null;
    return int.tryParse(value);
  }

  Future<void> setSwapKeyIndex(
    String swapMasterKeyFingerprint,
    int index,
  ) async {
    await _writeSecret(
      '${_Keys.swapKeyIndex}$swapMasterKeyFingerprint',
      index.toString(),
    );
  }

  /// Reserves on the shared canonical fingerprint authority before returning.
  Future<int> reserveSwapKeyIndex(String fingerprint, int count, int floor) =>
      (_allocationLocks[fingerprint] ??= Lock()).synchronized(() async {
        final stored = await getSwapKeyIndex(fingerprint);
        final current = stored != null && stored > floor ? stored : floor;
        await setSwapKeyIndex(fingerprint, current + count);
        return current;
      });

  // SECURE STORAGE — BULL_SDK SWAP OBJECTS
  Future<void> storeBtcLnSwap(BtcLnSwap swap) async {
    await _writeSecret(_swapBlobKey(swap.id), await swap.toJson());
  }

  Future<void> storeLbtcLnSwap(LbtcLnSwap swap) async {
    await _writeSecret(_swapBlobKey(swap.id), await swap.toJson());
  }

  Future<void> storeChainSwap(ChainSwap swap) async {
    await _writeSecret(_swapBlobKey(swap.id), await swap.toJson());
  }

  Future<String> _readSwapBlob(String swapId) async {
    final jsonSwap = await _readSecret(_swapBlobKey(swapId));
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
