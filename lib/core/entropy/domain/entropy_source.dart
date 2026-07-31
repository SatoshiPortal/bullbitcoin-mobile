import 'dart:typed_data';

/// Well-known source names used for domain separation in the pool.
///
/// [osRng] and [bdkRng] are the mandatory floor: `EntropyPool.extract`
/// refuses to produce output unless both were mixed since the last
/// extraction. Every other source is strictly additive and best-effort.
class EntropySourceName {
  static const osRng = 'os-rng';
  static const bdkRng = 'bdk-rng';
  static const cpuJitter = 'cpu-jitter';
  static const systemStats = 'system-stats';
  static const imu = 'imu';
  static const touch = 'touch';
  static const strengthen = 'strengthen';

  const EntropySourceName._();
}

/// A producer of entropy bytes to be folded into the [EntropyPool].
///
/// Sources never see or touch pool state: they only return bytes, and the
/// pool does all mixing internally. A source that fails must throw (or time
/// out); the collector skips it — a failed source contributes nothing but
/// can never subtract from the pool.
abstract class EntropySource {
  /// Domain-separation label, one of [EntropySourceName].
  String get name;

  /// Whether wallet creation must abort if this source fails.
  bool get mandatory;

  Future<Uint8List> collect();
}
