part of 'bdk_wallet_datasource.dart';

/// Only public descriptors cross this boundary. Reload the wallet for every
/// request so addresses revealed by another operation are never stale.
class _SyncParams {
  final String walletId;
  final String externalDescriptor;
  final String internalDescriptor;
  final bool isTestnet;
  final ElectrumConnection connection;
  final String databasePath;
  final bool fullDiscovery;

  _SyncParams({
    required this.walletId,
    required this.externalDescriptor,
    required this.internalDescriptor,
    required this.isTestnet,
    required this.connection,
    required this.databasePath,
    required this.fullDiscovery,
  });

  // Records compare by value. A setting change must not reuse the old client.
  Object get context => (
    walletId,
    externalDescriptor,
    internalDescriptor,
    isTestnet,
    databasePath,
    connection.url,
    connection.socks5,
    connection.effectiveTimeout,
    connection.retry,
    connection.validateDomain,
  );
}

class _DiscoveryStarted {}

class _SyncSucceeded {}

class BdkSyncException implements Exception {
  final String sourceType;
  final String message;
  const BdkSyncException(this.sourceType, this.message);
  @override
  String toString() => 'BdkSyncException($sourceType): $message';
}

class _SyncFailed {
  final String sourceType;
  final String message;
  final String stackTrace;
  final bool programmingError;

  _SyncFailed(Object error, StackTrace trace)
    : sourceType = error.runtimeType.toString(),
      message = error.toString(),
      stackTrace = trace.toString(),
      programmingError = error is Error;
}

class _StopSyncWorker {}

class _WorkerStart {
  final SendPort replies;
  final Future<void> Function(SendPort) entryPoint;
  _WorkerStart(this.replies, this.entryPoint);
}

Future<void> _startSyncWorker(_WorkerStart start) async {
  try {
    await start.entryPoint(start.replies);
  } catch (error, trace) {
    start.replies.send(_SyncFailed(error, trace));
  }
}

/// Each wallet owns a worker containing public data and a dedicated native client.
class _BdkSyncWorker {
  static int _nextDebugNumber = 0;
  final ReceivePort _events = ReceivePort();
  final Completer<SendPort> _ready = Completer<SendPort>();
  final Completer<void> _exited = Completer<void>();
  Completer<void>? _pending;
  void Function()? _onDiscoveryStarted;
  ({Object error, StackTrace trace})? _failure;
  Isolate? _isolate;
  bool _closed = false;
  bool _closing = false;

  static Future<_BdkSyncWorker> start({
    required Future<void> Function(SendPort) entryPoint,
  }) async {
    final worker = _BdkSyncWorker();
    worker._events.listen(worker._onEvent);
    // Startup can fail before spawn returns; start still awaits this same future.
    worker._ready.future.ignore();
    try {
      final isolate = await Isolate.spawn(
        _startSyncWorker,
        _WorkerStart(worker._events.sendPort, entryPoint),
        onError: worker._events.sendPort,
        onExit: worker._events.sendPort,
        debugName: 'bdk-sync-${_nextDebugNumber++}',
      );
      worker._isolate = isolate;
      if (worker._closed) isolate.kill(priority: Isolate.immediate);
      await worker._ready.future;
      return worker;
    } catch (_) {
      worker._finish();
      rethrow;
    }
  }

  void _onEvent(dynamic event) {
    switch (event) {
      case SendPort():
        _ready.complete(event);
      case _DiscoveryStarted():
        _onDiscoveryStarted?.call();
      case _SyncSucceeded():
        _onDiscoveryStarted = null;
        _pending?.complete();
        _pending = null;
      case _SyncFailed(
        :final sourceType,
        :final message,
        :final stackTrace,
        :final programmingError,
      ):
        final error = programmingError
            ? RemoteError('$sourceType: $message', stackTrace)
            : BdkSyncException(sourceType, message);
        final trace = StackTrace.fromString(stackTrace);
        _failure = (error: error, trace: trace);
        if (!_ready.isCompleted) _ready.completeError(error, trace);
        _pending?.completeError(error, trace);
        _pending = null;
        // The request loop may already have failed after its handshake.
        _finish();
      default:
        const error = BdkSyncException(
          'WorkerExit',
          'BDK sync worker exited unexpectedly',
        );
        if (!_ready.isCompleted) _ready.completeError(error);
        _pending?.completeError(error);
        _pending = null;
        _finish();
    }
  }

  Future<void> sync(
    _SyncParams params, {
    required void Function() onDiscoveryStarted,
  }) async {
    final port = await _ready.future;
    // A failure can arrive after the handshake but before a request is pending.
    final failure = _failure;
    if (failure != null) {
      Error.throwWithStackTrace(failure.error, failure.trace);
    }
    if (_closed || _closing) {
      throw const BdkSyncException('WorkerClosed', 'BDK sync worker is closed');
    }
    if (_pending != null) throw StateError('BDK sync already in progress');
    final pending = Completer<void>();
    _pending = pending;
    _onDiscoveryStarted = onDiscoveryStarted;
    port.send(params);
    return pending.future;
  }

  Future<void> close() async {
    if (_closed) return;
    if (!_closing) {
      _closing = true;
      final port = await _ready.future;
      port.send(_StopSyncWorker());
    }
    // Let the idle worker release its native client before it exits. Killing
    // the isolate immediately would skip that explicit native cleanup.
    await _exited.future.timeout(
      const Duration(seconds: 5),
      onTimeout: _finish,
    );
  }

  void _finish() {
    if (_closed) return;
    _closed = true;
    _onDiscoveryStarted = null;
    _isolate?.kill(priority: Isolate.immediate);
    _events.close();
    _exited.complete();
  }
}

Future<void> _runSyncWorker(SendPort replies) async {
  final requests = ReceivePort();
  replies.send(requests.sendPort);
  bdk.ElectrumClient? client;
  Object? context;

  try {
    await for (final message in requests) {
      if (message is _StopSyncWorker) break;
      final params = message as _SyncParams;
      try {
        if (params.context != context) {
          client?.dispose();
          client = null;
          context = params.context;
        }
        final connection = params.connection;
        final blockchain = client ??= _createElectrumClient(
          url: connection.url,
          socks5: connection.socks5,
          timeout: connection.effectiveTimeout,
          retry: connection.retry,
          validateDomain: connection.validateDomain,
        );
        final wallet = WalletModel.publicBdk(
          id: params.walletId,
          externalDescriptor: params.externalDescriptor,
          internalDescriptor: params.internalDescriptor,
          isTestnet: params.isTestnet,
        );
        final loaded = await BdkFacade.loadOrCreatePublicWallet(
          wallet,
          databasePath: params.databasePath,
        );
        final bdkWallet = loaded.wallet;
        try {
          final batchSize = _batchSizeFor(connection.stopGap);
          // First sync and database recovery discover addresses; client replacement alone does not.
          final discover = params.fullDiscovery || loaded.created;
          if (discover) replies.send(_DiscoveryStarted());
          final update = !discover
              ? blockchain.sync_(
                  request: bdkWallet.startSyncWithRevealedSpks().build(),
                  batchSize: batchSize,
                  fetchPrevTxouts: true,
                )
              : blockchain.fullScan(
                  request: bdkWallet.startFullScan().build(),
                  stopGap: connection.stopGap,
                  batchSize: batchSize,
                  fetchPrevTxouts: true,
                );
          bdkWallet.applyUpdate(update: update);
          final persister = bdk.Persister.newSqlite(path: params.databasePath);
          try {
            bdkWallet.persist(persister: persister);
          } finally {
            persister.dispose();
          }
        } finally {
          bdkWallet.dispose();
        }
        replies.send(_SyncSucceeded());
      } catch (error, stackTrace) {
        // Failure is terminal; release native state before the owner retires us.
        client?.dispose();
        client = null;
        replies.send(_SyncFailed(error, stackTrace));
        break;
      }
    }
  } finally {
    try {
      client?.dispose();
    } finally {
      requests.close();
    }
  }
}
