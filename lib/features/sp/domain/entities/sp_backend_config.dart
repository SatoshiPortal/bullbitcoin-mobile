import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';

/// The SP backend config (network + node URLs) bb-mobile persists itself.
///
/// The FFI create path does not write a reloadable config file, so the session
/// is reconstructed via `createFromSecret` from this stored config plus the
/// wallet's secret (matching how the silent wallet rebuilds its account).
///
/// Pure domain entity: serialization lives in `data/SpBackendConfigModel`.
///
/// Self-validating: both node URLs must be non-empty, so an invalid config
/// cannot exist. Consumers rely on this instead of re-checking `isNotEmpty`.
/// Immutable public identity of the wallet chosen when the SP account is created.
class SpSourceBinding {
  const SpSourceBinding({
    required this.walletId,
    required this.secretId,
    required this.externalDescriptor,
    required this.internalDescriptor,
    required this.spAddress,
  });

  final String walletId;
  final String secretId;
  final String externalDescriptor;
  final String internalDescriptor;
  final String spAddress;

  bool get isValid => [
    walletId,
    secretId,
    externalDescriptor,
    internalDescriptor,
    spAddress,
  ].every((value) => value.isNotEmpty);

  @override
  bool operator ==(Object other) =>
      other is SpSourceBinding &&
      walletId == other.walletId &&
      secretId == other.secretId &&
      externalDescriptor == other.externalDescriptor &&
      internalDescriptor == other.internalDescriptor &&
      spAddress == other.spAddress;

  @override
  int get hashCode => Object.hash(
    walletId,
    secretId,
    externalDescriptor,
    internalDescriptor,
    spAddress,
  );
}

class SpBackendConfig {
  final BitcoinNetwork network;

  /// Null only for legacy records that need independent identity verification.
  final SpSourceBinding? source;
  final String blindbitUrl;
  final String electrumUrl;
  final int fetchConcurrencyFactor;
  final int matchConcurrencyFactor;

  /// Throws on invalid input: for a config the code itself built, an invariant
  /// break is a programmer bug. Use [parse] for values that came from the user.
  SpBackendConfig({
    required this.network,
    this.source,
    required this.blindbitUrl,
    required this.electrumUrl,
    this.fetchConcurrencyFactor = SpConfig.defaultFetchConcurrencyFactor,
    this.matchConcurrencyFactor = SpConfig.defaultMatchConcurrencyFactor,
  }) {
    final reason = _invalidReason(
      blindbitUrl: blindbitUrl,
      electrumUrl: electrumUrl,
      fetchConcurrencyFactor: fetchConcurrencyFactor,
      matchConcurrencyFactor: matchConcurrencyFactor,
    );
    if (reason != null) throw ArgumentError(reason);
    if (source != null && !source!.isValid) {
      throw ArgumentError('Invalid SP source');
    }
  }

  /// Build from unvalidated input, reporting a broken invariant as
  /// [SpConfigInvalid] rather than throwing. The setup and settings forms feed
  /// user-typed values in, and an `ArgumentError` there would escape the
  /// use-case boundary, which only catches `Exception`.
  @useResult
  static Result<SpBackendConfig, SpFailure> parse({
    required BitcoinNetwork network,
    SpSourceBinding? source,
    required String blindbitUrl,
    required String electrumUrl,
    int fetchConcurrencyFactor = SpConfig.defaultFetchConcurrencyFactor,
    int matchConcurrencyFactor = SpConfig.defaultMatchConcurrencyFactor,
  }) {
    final reason = _invalidReason(
      blindbitUrl: blindbitUrl,
      electrumUrl: electrumUrl,
      fetchConcurrencyFactor: fetchConcurrencyFactor,
      matchConcurrencyFactor: matchConcurrencyFactor,
    );
    if (reason != null) return Err(SpConfigInvalid(reason));
    if (source != null && !source.isValid) {
      return const Err(SpConfigInvalid('Invalid SP source'));
    }
    return Ok(
      SpBackendConfig(
        network: network,
        source: source,
        blindbitUrl: blindbitUrl,
        electrumUrl: electrumUrl,
        fetchConcurrencyFactor: fetchConcurrencyFactor,
        matchConcurrencyFactor: matchConcurrencyFactor,
      ),
    );
  }

  /// The one place the invariants live, so the constructor and [parse] cannot
  /// disagree. Null when the values are valid.
  static String? _invalidReason({
    required String blindbitUrl,
    required String electrumUrl,
    required int fetchConcurrencyFactor,
    required int matchConcurrencyFactor,
  }) {
    if (blindbitUrl.trim().isEmpty || electrumUrl.trim().isEmpty) {
      return 'SP backend URLs must not be empty';
    }
    if (fetchConcurrencyFactor < 1 ||
        fetchConcurrencyFactor > SpConfig.maxFetchConcurrencyFactor) {
      return 'SP fetch concurrency factor is out of range';
    }
    if (matchConcurrencyFactor < 1 ||
        matchConcurrencyFactor > SpConfig.maxMatchConcurrencyFactor) {
      return 'SP match concurrency factor is out of range';
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is SpBackendConfig &&
      other.network == network &&
      other.source == source &&
      other.blindbitUrl == blindbitUrl &&
      other.electrumUrl == electrumUrl &&
      other.fetchConcurrencyFactor == fetchConcurrencyFactor &&
      other.matchConcurrencyFactor == matchConcurrencyFactor;

  @override
  int get hashCode => Object.hash(
    network,
    source,
    blindbitUrl,
    electrumUrl,
    fetchConcurrencyFactor,
    matchConcurrencyFactor,
  );
}
