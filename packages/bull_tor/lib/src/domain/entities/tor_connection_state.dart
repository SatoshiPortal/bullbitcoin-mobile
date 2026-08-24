import '../tor_failure.dart';
import 'tor_route.dart';
import 'tor_transport.dart';

enum TorDiagnostic {
  offline,
  filtering,
  cantReachTor,
  clockSkewed,
  cantBootstrap,
  unknown;

  bool get suggestsCensorship =>
      this == TorDiagnostic.filtering || this == TorDiagnostic.cantReachTor;
}

/// Current truth about the selected Tor source.
sealed class TorConnectionState {
  const TorConnectionState();

  TorSource? get source => switch (this) {
    TorUninitialized() => null,
    TorStopped(:final source) ||
    TorConnecting(:final source) ||
    TorUnavailable(:final source) => source,
    TorReady(:final route) => route.source,
  };

  bool get isReady => this is TorReady;
}

final class TorUninitialized extends TorConnectionState {
  const TorUninitialized();
}

final class TorStopped extends TorConnectionState {
  @override
  final TorSource source;

  const TorStopped(this.source);
}

final class TorConnecting extends TorConnectionState {
  @override
  final TorSource source;
  final double? progress;
  final TorDiagnostic? diagnostic;
  final TorTransport? transport;

  const TorConnecting({
    required this.source,
    this.progress,
    this.diagnostic,
    this.transport,
  });
}

final class TorReady extends TorConnectionState {
  final TorRoute route;

  const TorReady(this.route);
}

final class TorUnavailable extends TorConnectionState {
  @override
  final TorSource source;
  final TorFailure failure;

  const TorUnavailable({required this.source, required this.failure});
}
