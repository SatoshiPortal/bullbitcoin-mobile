import '../tor_failure.dart';
import 'tor_route.dart';
import 'tor_transport.dart';

enum TorDiagnostic {
  offline,

  /// The device has a network but Tor gets no connection through it: either
  /// that network has no internet access, or it blocks Tor. Nothing on the
  /// device can tell the two apart without contacting a third party.
  noInternetOrBlocked,
  filtering,
  cantReachTor,
  clockSkewed,
  cantBootstrap,
  unknown;

  /// Tor's own evidence that the network interferes with it.
  bool get suggestsCensorship =>
      this == TorDiagnostic.filtering || this == TorDiagnostic.cantReachTor;

  /// Snowflake may get through: worth trying, cheap when it cannot help.
  bool get worthSnowflake =>
      suggestsCensorship || this == TorDiagnostic.noInternetOrBlocked;
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

  /// This attempt circumvents a network that appeared to block direct Tor.
  final bool circumvention;

  /// When this attempt gives up if Tor is still not ready.
  final DateTime? deadline;

  const TorConnecting({
    required this.source,
    this.progress,
    this.diagnostic,
    this.transport,
    this.circumvention = false,
    this.deadline,
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
