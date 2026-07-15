import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_config.dart';

/// The SP backend config (network + node URLs) bb-mobile persists itself.
///
/// The FFI create path does not write a reloadable config file, so the session
/// is reconstructed via `createFromMnemonic` from this stored config plus the
/// wallet mnemonic (matching how the silent wallet rebuilds its account).
///
/// Pure domain entity: serialization lives in `data/models/SpBackendConfigModel`.
///
/// Self-validating: both node URLs must be non-empty, so an invalid config
/// cannot exist. Consumers rely on this instead of re-checking `isNotEmpty`.
class SpBackendConfig {
  final SpNetwork network;
  final String blindbitUrl;
  final String electrumUrl;
  final int fetchConcurrencyFactor;
  final int matchConcurrencyFactor;

  SpBackendConfig({
    required this.network,
    required this.blindbitUrl,
    required this.electrumUrl,
    this.fetchConcurrencyFactor = SpConfig.defaultFetchConcurrencyFactor,
    this.matchConcurrencyFactor = SpConfig.defaultMatchConcurrencyFactor,
  }) {
    if (blindbitUrl.trim().isEmpty || electrumUrl.trim().isEmpty) {
      throw ArgumentError('SP backend URLs must not be empty');
    }
    if (fetchConcurrencyFactor < 1 ||
        fetchConcurrencyFactor > SpConfig.maxFetchConcurrencyFactor) {
      throw ArgumentError('SP fetch concurrency factor is out of range');
    }
    if (matchConcurrencyFactor < 1 ||
        matchConcurrencyFactor > SpConfig.maxMatchConcurrencyFactor) {
      throw ArgumentError('SP match concurrency factor is out of range');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is SpBackendConfig &&
      other.network == network &&
      other.blindbitUrl == blindbitUrl &&
      other.electrumUrl == electrumUrl &&
      other.fetchConcurrencyFactor == fetchConcurrencyFactor &&
      other.matchConcurrencyFactor == matchConcurrencyFactor;

  @override
  int get hashCode => Object.hash(
    network,
    blindbitUrl,
    electrumUrl,
    fetchConcurrencyFactor,
    matchConcurrencyFactor,
  );
}
