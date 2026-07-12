import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';

/// The slow-preset feerate in sat/vB, also the send default. One literal so the
/// two track together; Dart cannot read an enum field in a const expression, so
/// they share this instead of `FeeratePreset.slow.satPerVb`.
const int _slowFeerateSatPerVb = 1;

/// A named feerate choice offered on the send amount page, in sat/vB. The
/// sat/vB values live here; the display labels are mapped in the presentation
/// layer (see FeeratePresetL10n) so domain stays Flutter- and l10n-free.
enum FeeratePreset {
  slow(_slowFeerateSatPerVb),
  normal(3),
  fast(10);

  final int satPerVb;

  const FeeratePreset(this.satPerVb);
}

/// Static configuration for the Silent Payments feature.
///
/// Pure constants only. No business logic, no external dependencies beyond
/// the domain network enum.
abstract class SpConfig {
  static const String accountName = 'sp';

  /// Default send feerate in sat/vB: the slow preset.
  static const int defaultFeerateSatPerVb = _slowFeerateSatPerVb;

  /// Rough blocks-per-day used to map a "months/weeks ago" scan start to a
  /// block height. Mainnet pace; test networks mine on demand, so on those the
  /// time-to-height mapping is only indicative.
  static const int blocksPerDay = 144;

  /// Rough minutes-per-block, used to estimate the age of a scanned height from
  /// how far behind the chain tip it is. Mainnet pace; only indicative on test
  /// networks that mine on demand.
  static const int minutesPerBlock = 10;

  /// Sentinel file placed inside `{appDocs}/{accountName}` BEFORE the account
  /// dir is recursively deleted on revoke. If the delete subsequently fails
  /// (e.g. transient file-locked on Android/iOS because the SP notification
  /// thread still holds the sqlite handle, or iOS document-protection
  /// denial), the repository refuses to load any wallet from a dir containing
  /// this file. This prevents a stale on-disk wallet from being reloaded
  /// after a failed revoke.
  static const String revokedSentinelFile = '.revoked';

  /// bwk's per-directory advisory-lock sentinel, `{accountName}/.lock`. bwk
  /// holds an OS flock on it to refuse a second CROSS-process opener; on mobile
  /// there is only one process, so a lock present at open time is always a
  /// disposed session whose Rust handle Dart has not GC'd yet. The repository
  /// clears it before reopening (sqlite WAL keeps the brief in-process overlap
  /// safe). Must match bwk persist's lock filename.
  static const String lockFile = '.lock';

  static const Map<SpNetwork, String> defaultBlindbitUrl = {
    SpNetwork.bitcoin: 'https://blindbit.pythcoiner.dev',
    SpNetwork.signet: 'https://blindbit-signet.bullbitcoin.com',
    SpNetwork.testnet: 'https://blindbit-testnet.bullbitcoin.com',
  };

  static const Map<SpNetwork, String> defaultElectrumUrl = {
    SpNetwork.bitcoin: 'ssl://electrum.pythcoiner.dev:50002',
    SpNetwork.signet: 'ssl://electrum-signet.bullbitcoin.com:50002',
    SpNetwork.testnet: 'ssl://electrum-testnet.bullbitcoin.com:50002',
  };

  // Regtest URLs come from getRegtestDefaults() at runtime, not hardcoded here.
}
