import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

/// Advisory server observation. Never a quote, reservation or review token.
final class ArkBoardMinimum {
  final ArkAccountConfig config;
  final Sats minimum;
  final DateTime observedAt;

  const ArkBoardMinimum({
    required this.config,
    required this.minimum,
    required this.observedAt,
  });

  static ArkBoardMinimum? fromSnapshot(
    ArkAccountConfig config,
    ArkSnapshot snapshot,
  ) {
    final minimum = snapshot.serverInfo?.minimumBoard;
    if (snapshot.account != config.id ||
        snapshot.stale ||
        minimum == null ||
        (snapshot.serverInfo?.serverUri != null &&
            snapshot.serverInfo?.serverUri != config.arkUrl)) {
      return null;
    }
    return ArkBoardMinimum(
      config: config,
      minimum: minimum,
      observedAt: snapshot.observedAt,
    );
  }

  DateTime get expiresAt => observedAt.add(const Duration(minutes: 5));

  Sats? forConfig(ArkAccountConfig config, {DateTime? now}) {
    final current = (now ?? DateTime.now()).toUtc();
    if (_binding(config) != _binding(this.config) ||
        current.isBefore(observedAt) ||
        !current.isBefore(expiresAt)) {
      return null;
    }
    return minimum;
  }

  static Object _binding(ArkAccountConfig config) => (
    config.id,
    config.arkUrl,
    config.primaryEsploraUrl,
    config.fallbackEsploraUrl,
    config.renewalThresholdBlocks,
  );
}
