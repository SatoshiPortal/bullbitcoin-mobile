import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';

/// The SP backend config (network + node URLs) bb-mobile persists itself.
///
/// The FFI create path does not write a reloadable config file, so the session
/// is reconstructed via `createFromScanKey` from this stored config plus the
/// scan credential the custody package derives for the default wallet.
///
/// Pure domain entity: serialization lives in `data/SpBackendConfigModel`.
///
/// Self-validating: both node URLs must be non-empty, so an invalid config
/// cannot exist. Consumers rely on this instead of re-checking `isNotEmpty`.
class SpBackendConfig {
  final BitcoinNetwork network;
  final String blindbitUrl;
  final String electrumUrl;
  final int fetchConcurrencyFactor;
  final int matchConcurrencyFactor;

  /// Throws on invalid input: for a config the code itself built, an invariant
  /// break is a programmer bug. Use [parse] for values that came from the user.
  SpBackendConfig({
    required this.network,
    required this.blindbitUrl,
    required this.electrumUrl,
    this.fetchConcurrencyFactor = SpConfig.defaultFetchConcurrencyFactor,
    this.matchConcurrencyFactor = SpConfig.defaultMatchConcurrencyFactor,
  }) {
    final failure = _invalid(
      blindbitUrl: blindbitUrl,
      electrumUrl: electrumUrl,
      fetchConcurrencyFactor: fetchConcurrencyFactor,
      matchConcurrencyFactor: matchConcurrencyFactor,
    );
    if (failure != null) throw ArgumentError(failure.logMessage);
  }

  /// Build from unvalidated input, reporting a broken invariant as
  /// [SpConfigInvalid] rather than throwing. The setup and settings forms feed
  /// user-typed values in, and an `ArgumentError` there would escape the
  /// use-case boundary, which only catches `Exception`.
  @useResult
  static Result<SpBackendConfig, SpFailure> parse({
    required BitcoinNetwork network,
    required String blindbitUrl,
    required String electrumUrl,
    int fetchConcurrencyFactor = SpConfig.defaultFetchConcurrencyFactor,
    int matchConcurrencyFactor = SpConfig.defaultMatchConcurrencyFactor,
  }) {
    final failure = _invalid(
      blindbitUrl: blindbitUrl,
      electrumUrl: electrumUrl,
      fetchConcurrencyFactor: fetchConcurrencyFactor,
      matchConcurrencyFactor: matchConcurrencyFactor,
    );
    if (failure != null) return Err(failure);
    return Ok(
      SpBackendConfig(
        network: network,
        blindbitUrl: blindbitUrl,
        electrumUrl: electrumUrl,
        fetchConcurrencyFactor: fetchConcurrencyFactor,
        matchConcurrencyFactor: matchConcurrencyFactor,
      ),
    );
  }

  /// Whether [url] names a Tor `.onion` host. The SP client (bwk) opens its
  /// own sockets with no proxy, so such a host is unreachable, and resolving
  /// it would hand the hidden-service name to the network's DNS resolver.
  /// The core Electrum connector refuses the same case for the same reason.
  static bool isOnionUrl(String url) {
    final normalized = url.trim();
    final uri = Uri.tryParse(
      normalized.contains('://') ? normalized : '//$normalized',
    );
    if (uri == null || !uri.hasAuthority) return false;
    final name = uri.host.toLowerCase();
    return name.endsWith('.onion') || name.endsWith('.onion.');
  }

  /// The one place the invariants live, so the constructor and [parse] cannot
  /// disagree. Null when the values are valid.
  static SpFailure? _invalid({
    required String blindbitUrl,
    required String electrumUrl,
    required int fetchConcurrencyFactor,
    required int matchConcurrencyFactor,
  }) {
    if (blindbitUrl.trim().isEmpty || electrumUrl.trim().isEmpty) {
      return const SpConfigInvalid('SP backend URLs must not be empty');
    }
    if (blindbitUrl.contains('@') || electrumUrl.contains('@')) {
      return const SpConfigInvalid('SP backend URLs must not contain userinfo');
    }
    if (isOnionUrl(blindbitUrl) || isOnionUrl(electrumUrl)) {
      return const SpBackendOnionUnsupported('SP backend URL is an onion host');
    }
    if (fetchConcurrencyFactor < 1 ||
        fetchConcurrencyFactor > SpConfig.maxFetchConcurrencyFactor) {
      return const SpConfigInvalid(
        'SP fetch concurrency factor is out of range',
      );
    }
    if (matchConcurrencyFactor < 1 ||
        matchConcurrencyFactor > SpConfig.maxMatchConcurrencyFactor) {
      return const SpConfigInvalid(
        'SP match concurrency factor is out of range',
      );
    }
    return null;
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
