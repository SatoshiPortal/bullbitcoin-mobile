import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

/// Every LWK operation goes through [withPublicWallet]/[withPrivateWallet]:
/// two wollet instances on the same on-disk cache directory corrupt each
/// other (torn reads panic in the native library — SIGABRT — or surface as
/// `UpdateOnDifferentStatus`), so access is serialized per directory within
/// the isolate and guarded across isolates via a freshness-gated marker file
/// (the workmanager background isolate syncs in the same process, where both
/// Dart locks and fcntl file locks cannot serialize two isolates).
class LwkFacade {
  static final Map<String, Lock> _dirLocks = {};

  static Future<String> _getDbPath(String walletIdHex) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/$walletIdHex';
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  static Future<T> _guarded<T>(
    String walletIdHex,
    Future<T> Function(String dbPath) action,
  ) async {
    final dbPath = await _getDbPath(walletIdHex);
    final lock = _dirLocks.putIfAbsent(dbPath, Lock.new);
    return lock.synchronized(() async {
      final marker = _CrossIsolateDirMarker(dbPath);
      await marker.acquire();
      try {
        return await action(dbPath);
      } finally {
        await marker.release();
      }
    });
  }

  /// Opens the watch-only wollet for [walletModel] and runs [action] with
  /// exclusive access to its cache directory.
  static Future<T> withPublicWallet<T>(
    WalletModel walletModel,
    Future<T> Function(lwk.Wallet wallet) action,
  ) async {
    if (walletModel is! PublicLwkWalletModel) {
      throw Exception('Wallet is not an LWK wallet');
    }
    // Errors (including LwkError) propagate untouched: callers map them and
    // detect recoverable ones like UpdateOnDifferentStatus.
    return _guarded(walletModel.hexId, (dbPath) async {
      final network = walletModel.isTestnet
          ? lwk.LiquidNetwork.testnet
          : lwk.LiquidNetwork.mainnet;
      final descriptor = lwk.Descriptor(
        ctDescriptor: walletModel.combinedCtDescriptor,
      );
      final wallet = await lwk.Wallet.init(
        network: network,
        dbpath: dbPath,
        descriptor: descriptor,
      );
      return action(wallet);
    });
  }

  /// Opens the signing wollet for [walletModel] and runs [action] with
  /// exclusive access to its cache directory.
  static Future<T> withPrivateWallet<T>(
    WalletModel walletModel,
    Future<T> Function(lwk.Wallet wallet) action,
  ) async {
    if (walletModel is! PrivateLwkWalletModel) {
      throw Exception('Wallet is not an LWK wallet');
    }
    return _guarded(walletModel.hexId, (dbPath) async {
      final network = walletModel.isTestnet
          ? lwk.LiquidNetwork.testnet
          : lwk.LiquidNetwork.mainnet;
      final descriptor = await lwk.Descriptor.newConfidential(
        mnemonic: walletModel.mnemonic,
        network: network,
      );
      final wallet = await lwk.Wallet.init(
        network: network,
        dbpath: dbPath,
        descriptor: descriptor,
      );
      return action(wallet);
    });
  }

  static Future<void> delete(WalletModel walletModel) async {
    await _guarded(walletModel.hexId, (dbPath) async {
      try {
        final dbFile = File(dbPath);

        if (!await dbFile.exists()) throw WalletError.notFound(walletModel.id);
        log.fine('Found LwkDb');
        await dbFile.delete(recursive: true);
      } catch (e) {
        log.warning('Failed to delete LwkDb', error: e);
        rethrow;
      }
    });
  }
}

/// Advisory cross-isolate guard for one wollet cache directory.
///
/// Both engines (main + workmanager) live in one process, so neither Dart
/// locks nor fcntl locks (process-owned) can serialize them; instead each
/// holder writes `<dbPath>.lwkguard` with its owner id and a timestamp it
/// refreshes while working. Waiters poll until the marker is gone or stale.
/// The stale TTL keeps a crashed holder from wedging the app, and the wait
/// deadline prefers a (rare, recoverable) collision over blocking forever.
class _CrossIsolateDirMarker {
  static const _staleAfter = Duration(seconds: 60);
  static const _maxWait = Duration(seconds: 45);
  static const _refreshEvery = Duration(seconds: 20);
  static const _pollEvery = Duration(milliseconds: 200);

  static final String _isolateOwner =
      '$pid-${Isolate.current.hashCode}-'
      '${DateTime.now().microsecondsSinceEpoch}';

  final String _markerPath;
  Timer? _refreshTimer;

  _CrossIsolateDirMarker(String dbPath) : _markerPath = '$dbPath.lwkguard';

  File get _file => File(_markerPath);

  Future<void> acquire() async {
    final deadline = DateTime.now().add(_maxWait);
    while (true) {
      final holder = await _freshHolder();
      if (holder == null || holder == _isolateOwner) break;
      if (DateTime.now().isAfter(deadline)) {
        log.warning(
          'LWK dir guard: still held by $holder after $_maxWait — '
          'proceeding anyway to avoid wedging the app',
        );
        break;
      }
      await Future<void>.delayed(_pollEvery);
    }
    await _write();
    _refreshTimer = Timer.periodic(_refreshEvery, (_) => _write());
  }

  Future<void> release() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    try {
      final content = await _readContent();
      if (content?['owner'] == _isolateOwner) await _file.delete();
    } catch (_) {
      // Best effort; a leftover marker expires via the stale TTL.
    }
  }

  Future<String?> _freshHolder() async {
    final content = await _readContent();
    if (content == null) return null;
    final ts = DateTime.tryParse(content['ts'] as String? ?? '');
    if (ts == null || DateTime.now().difference(ts) > _staleAfter) return null;
    return content['owner'] as String?;
  }

  Future<Map<String, dynamic>?> _readContent() async {
    try {
      if (!await _file.exists()) return null;
      return jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      // Torn marker write from the other isolate; treat as absent.
      return null;
    }
  }

  Future<void> _write() async {
    try {
      await _file.writeAsString(
        jsonEncode({
          'owner': _isolateOwner,
          'ts': DateTime.now().toIso8601String(),
        }),
        flush: true,
      );
    } catch (e) {
      log.warning('LWK dir guard: failed to write marker', error: e);
    }
  }
}
