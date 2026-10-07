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

  /// A problem on the device itself, which no other transport can route
  /// around: switching to Snowflake would fail the same way.
  bool get blocksEveryTransport =>
      this == TorDiagnostic.offline || this == TorDiagnostic.clockSkewed;
}

/// What arti says about a bootstrap beyond its progress fraction.
///
/// Arti's own English wording, shown as a caption and reported in support
/// diagnostics. It is fixed library text plus, for a skewed clock, the skew,
/// so it never carries secrets or addresses; it is never localized either,
/// which is why the UI shows it beneath a translated explanation, not instead
/// of one.
final class TorBootstrapDetail {
  /// Why arti believes it is stuck, e.g. "Clock is skewed by 2 hours".
  final String? blockage;

  /// The bootstrap step arti is on, e.g. "fetching microdescriptors 120/300".
  ///
  /// Null until the `onion` binding reports it; the embedded backend fills it
  /// from the status stream once it does, and every consumer of this type
  /// already shows it.
  final String? stage;

  const TorBootstrapDetail({this.blockage, this.stage});
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
  final TorBootstrapDetail? detail;

  const TorConnecting({
    required this.source,
    this.progress,
    this.diagnostic,
    this.transport,
    this.detail,
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
