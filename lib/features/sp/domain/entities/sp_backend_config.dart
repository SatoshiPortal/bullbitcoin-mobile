import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';

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

  SpBackendConfig({
    required this.network,
    required this.blindbitUrl,
    required this.electrumUrl,
  }) {
    if (blindbitUrl.trim().isEmpty || electrumUrl.trim().isEmpty) {
      throw ArgumentError('SP backend URLs must not be empty');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is SpBackendConfig &&
      other.network == network &&
      other.blindbitUrl == blindbitUrl &&
      other.electrumUrl == electrumUrl;

  @override
  int get hashCode => Object.hash(network, blindbitUrl, electrumUrl);
}
