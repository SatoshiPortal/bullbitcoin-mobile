import 'dart:async';
import 'wallet_source_session.dart';

/// Serializes source access per key. Timeout is cooperative: it reports to the
/// caller, but the tail remains held until the underlying operation completes.
abstract interface class WalletSourceOperationCoordinator {
  Future<T> runExclusive<T>(
    WalletSourceKey key,
    Future<T> Function(WalletSourceSession session) operation, {
    Duration timeout = const Duration(seconds: 30),
    bool allowRetired = false,
  });
}

final class WalletSourceKey {
  final String walletId;
  final String chain;
  final String network;
  const WalletSourceKey(this.walletId, this.chain, this.network);
  @override
  bool operator ==(Object other) =>
      other is WalletSourceKey &&
      other.walletId == walletId &&
      other.chain == chain &&
      other.network == network;
  @override
  int get hashCode => Object.hash(walletId, chain, network);
}

final class InMemoryWalletSourceOperationCoordinator
    implements WalletSourceOperationCoordinator {
  final Map<WalletSourceKey, Future<void>> _tails = {};
  final Set<WalletSourceKey> _retired = {};
  final Duration defaultTimeout;
  InMemoryWalletSourceOperationCoordinator({
    this.defaultTimeout = const Duration(seconds: 30),
  });

  @override
  Future<T> runExclusive<T>(
    WalletSourceKey key,
    Future<T> Function(WalletSourceSession session) operation, {
    Duration timeout = const Duration(seconds: 30),
    bool allowRetired = false,
  }) async {
    final previous = _tails[key] ?? Future<void>.value();
    final completer = Completer<void>();
    _tails[key] = completer.future;
    final result = Completer<T>();
    final duration = timeout == const Duration(seconds: 30)
        ? defaultTimeout
        : timeout;
    Timer? timer;
    Future<void> finish() async {
      timer?.cancel();
      if (!completer.isCompleted) completer.complete();
      if (identical(_tails[key], completer.future)) _tails.remove(key);
    }

    Future<void>(() async {
      try {
        await previous;
        if (_retired.contains(key) && !allowRetired) {
          throw StateError('wallet source is retired');
        }
        final session = _CoordinatorSession(
          onRetire: () => _retired.add(key),
          onReactivate: () => _retired.remove(key),
        );
        late Future<T> operationFuture;
        try {
          operationFuture = operation(session);
        } catch (error, stackTrace) {
          operationFuture = Future<T>.error(error, stackTrace);
        }
        timer = Timer(duration, () {
          if (!result.isCompleted) {
            result.completeError(
              TimeoutException('Wallet source operation timed out'),
            );
          }
        });
        operationFuture
            .then(
              (value) {
                if (!result.isCompleted) result.complete(value);
              },
              onError: (Object error, StackTrace stackTrace) {
                if (!result.isCompleted) {
                  result.completeError(error, stackTrace);
                }
              },
            )
            .whenComplete(() async {
              await session.close();
              await finish();
            });
      } catch (error, stackTrace) {
        if (!result.isCompleted) result.completeError(error, stackTrace);
        await finish();
      }
    });
    return result.future;
  }
}

final class _CoordinatorSession implements WalletSourceSession {
  final void Function() _onRetire;
  final void Function() _onReactivate;
  bool _closed = false;

  _CoordinatorSession({required this._onRetire, required this._onReactivate});
  @override
  bool get isClosed => _closed;
  @override
  void ensureOpen() {
    if (_closed) throw StateError('source session is closed');
  }

  @override
  void retire() {
    ensureOpen();
    _onRetire();
  }

  @override
  void reactivate() {
    ensureOpen();
    _onReactivate();
  }

  @override
  Future<void> close() async {
    _closed = true;
  }
}
