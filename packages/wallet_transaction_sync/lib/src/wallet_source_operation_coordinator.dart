import 'dart:async';

import 'wallet_source_session.dart';

enum WalletOperationPriority { foreground, background }

enum WalletOperationKind { refresh, synchronize, discover, delete, reactivate }

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

final class WalletSourceClaim {
  final String key;
  final int generation;
  final String ownerToken;
  final WalletOperationKind kind;
  final WalletOperationPriority priority;
  const WalletSourceClaim({
    required this.key,
    required this.generation,
    required this.ownerToken,
    required this.kind,
    required this.priority,
  });
}

/// Session capability exposed only by durable coordination.
abstract interface class WalletSourceClaimedSession
    implements WalletSourceSession {
  WalletSourceClaim get claim;
}

abstract interface class WalletSourceOperationCoordinator {
  Future<T> runExclusive<T>(
    WalletSourceKey key,
    Future<T> Function(WalletSourceSession session) operation, {
    Duration? timeout = const Duration(seconds: 30),
    bool allowRetired = false,
    WalletOperationKind kind = WalletOperationKind.refresh,
    WalletOperationPriority priority = WalletOperationPriority.foreground,
  });
}

/// The compatibility coordinator intentionally remains process-local.
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
    Duration? timeout = const Duration(seconds: 30),
    bool allowRetired = false,
    WalletOperationKind kind = WalletOperationKind.refresh,
    WalletOperationPriority priority = WalletOperationPriority.foreground,
  }) async {
    final previous = _tails[key] ?? Future<void>.value();
    final done = Completer<void>();
    _tails[key] = done.future;
    final result = Completer<T>();
    final duration = timeout == const Duration(seconds: 30)
        ? defaultTimeout
        : timeout;
    Timer? timer;
    Future<void> finish() async {
      timer?.cancel();
      if (!done.isCompleted) done.complete();
      if (identical(_tails[key], done.future)) _tails.remove(key);
    }

    Future<void>(() async {
      try {
        await previous;
        if (_retired.contains(key) && !allowRetired) {
          throw StateError('wallet source is retired');
        }
        final session = _MemorySession(
          onRetire: () => _retired.add(key),
          onReactivate: () => _retired.remove(key),
        );
        late Future<T> future;
        try {
          future = operation(session);
        } catch (error, stack) {
          future = Future<T>.error(error, stack);
        }
        if (duration != null) {
          timer = Timer(duration, () {
            if (!result.isCompleted) {
              result.completeError(
                TimeoutException('Wallet source operation timed out'),
              );
            }
          });
        }
        future
            .then(
              (value) {
                if (!result.isCompleted) result.complete(value);
              },
              onError: (Object e, StackTrace s) {
                if (!result.isCompleted) result.completeError(e, s);
              },
            )
            .whenComplete(() async {
              await session.close();
              await finish();
            });
      } catch (error, stack) {
        if (!result.isCompleted) result.completeError(error, stack);
        await finish();
      }
    });
    return result.future;
  }
}

final class _MemorySession implements WalletSourceSession {
  final void Function() onRetire, onReactivate;
  bool _closed = false;
  _MemorySession({required this.onRetire, required this.onReactivate});
  @override
  bool get isClosed => _closed;
  @override
  void ensureOpen() {
    if (_closed) throw StateError('source session is closed');
  }

  @override
  void retire() {
    ensureOpen();
    onRetire();
  }

  @override
  void reactivate() {
    ensureOpen();
    onReactivate();
  }

  @override
  Future<void> close() async {
    _closed = true;
  }
}
