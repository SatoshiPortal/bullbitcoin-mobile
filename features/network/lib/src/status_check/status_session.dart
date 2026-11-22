import 'dart:async';

import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'domain/check_service_status_usecase.dart';
import 'domain/network_failure.dart';
import 'domain/service_status.dart';

NetworkStatus buildNetworkStatus(
  CheckServiceStatusUsecase Function() createCheck,
) => NetworkStatus._(createCheck);

final class NetworkStatus {
  final CheckServiceStatusUsecase Function() _createCheck;

  const NetworkStatus._(this._createCheck);

  /// Creates an independent session. Its consumer owns [StatusSession.close].
  StatusSession session() => StatusSession._(_createCheck());
}

final class StatusSnapshot {
  final AllServicesStatus services;
  final bool isRefreshing;

  const StatusSnapshot({
    this.services = const AllServicesStatus(),
    this.isRefreshing = false,
  });
}

final class StatusSession {
  final CheckServiceStatusUsecase _check;
  final _updates =
      StreamController<Result<StatusSnapshot, NetworkFailure>>.broadcast();
  StatusSnapshot _snapshot = const StatusSnapshot();
  NetworkFailure? _failure;
  int _generation = 0;

  StatusSession._(this._check);

  /// The latest available rows, including when the last refresh failed.
  StatusSnapshot get snapshot => _snapshot;

  /// Replays the current snapshot and any current failure, then observes
  /// loading, partial rows and terminal results. Subscribing starts no probes.
  Stream<Result<StatusSnapshot, NetworkFailure>> watch() =>
      Stream.multi((listener) {
        if (_updates.isClosed) {
          listener.close();
          return;
        }
        final subscription = _updates.stream.listen(
          listener.add,
          onDone: listener.close,
        );
        listener.onCancel = subscription.cancel;
        listener.add(Ok(_snapshot));
        if (_failure case final failure?) listener.add(Err(failure));
      }, isBroadcast: true);

  /// Refreshes the default wallet's network. Superseded or closed checks
  /// return an interruption without publishing their results.
  @useResult
  Future<Result<AllServicesStatus, NetworkFailure>> check() async {
    if (_updates.isClosed) return const Err(StatusCheckInterruptedFailure());
    final generation = ++_generation;
    _failure = null;
    _publish(StatusSnapshot(services: _snapshot.services, isRefreshing: true));

    final result = await _check.execute(
      initialStatus: _snapshot.services,
      onUpdate: (services) {
        if (generation != _generation) return;
        _publish(StatusSnapshot(services: services, isRefreshing: true));
      },
    );
    if (generation != _generation) {
      return const Err(StatusCheckInterruptedFailure());
    }

    switch (result) {
      case Ok(:final value):
        _publish(StatusSnapshot(services: value));
      case Err(:final failure):
        _failure = failure;
        _snapshot = StatusSnapshot(services: _snapshot.services);
        _updates.add(Err(failure));
    }
    return result;
  }

  void _publish(StatusSnapshot snapshot) {
    _snapshot = snapshot;
    _updates.add(Ok(snapshot));
  }

  Future<void> close() async {
    _generation++;
    await _updates.close();
  }
}
