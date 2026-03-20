import 'package:freezed_annotation/freezed_annotation.dart';

part 'dlc_connection_status.freezed.dart';

enum DlcApiHealth { unknown, healthy, degraded, unreachable }

@freezed
abstract class DlcConnectionStatus with _$DlcConnectionStatus {
  const factory DlcConnectionStatus({
    required DlcApiHealth apiHealth,
    /// Milliseconds of last measured round-trip latency, null if unreachable
    int? latencyMs,
    /// Version string reported by the DLC engine API
    String? engineVersion,
    /// Human-readable status message (e.g. error description)
    String? message,
    /// Timestamp of the last check (ISO 8601)
    String? lastCheckedAt,
  }) = _DlcConnectionStatus;
  const DlcConnectionStatus._();

  bool get isHealthy => apiHealth == DlcApiHealth.healthy;
}
