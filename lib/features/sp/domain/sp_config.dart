import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:primitives/primitives.dart';

/// Static configuration for the Silent Payments feature.
///
/// Pure constants only. No business logic, no external dependencies beyond
/// the domain network enum.
abstract class SpConfig {
  static const int dustLimitSat = 600;

  static const int defaultFetchConcurrencyFactor = 12;
  static const int defaultMatchConcurrencyFactor = 1;
  static const int maxFetchConcurrencyFactor = 32;
  static const int maxMatchConcurrencyFactor = 4;

  /// Rough blocks-per-day used to map a "months/weeks ago" scan start to a
  /// block height. Mainnet pace; test networks mine on demand, so on those the
  /// time-to-height mapping is only indicative.
  static const int blocksPerDay = 144;

  /// Rough minutes-per-block, used to estimate the age of a scanned height from
  /// how far behind the chain tip it is. Mainnet pace; only indicative on test
  /// networks that mine on demand.
  static const int minutesPerBlock = 10;

  /// How long to wait for the broadcast notification. Long enough for a slow
  /// electrum round trip, short enough that the send screen is not stuck for
  /// good when the notification never arrives.
  static const Duration broadcastTimeout = Duration(seconds: 30);

  /// Backend URLs baked in for a network, or null when they have to be fetched
  /// at runtime instead.
  ///
  /// A switch rather than a pair of maps: every network is named, so adding one
  /// to [BitcoinNetwork] is a compile error here instead of a silently missing
  /// URL, and the two URLs of a network cannot drift apart.
  static SpBackendDefaults? staticDefaults(BitcoinNetwork network) =>
      switch (network) {
        BitcoinNetwork.mainnet => const SpBackendDefaults(
          blindbitUrl: 'https://blindbit.pythcoiner.dev',
          electrumUrl: 'ssl://electrum.pythcoiner.dev:50002',
        ),
        BitcoinNetwork.signet => const SpBackendDefaults(
          blindbitUrl: 'https://blindbit-signet.bullbitcoin.com',
          electrumUrl: 'ssl://electrum-signet.bullbitcoin.com:50002',
        ),
        BitcoinNetwork.testnet => const SpBackendDefaults(
          blindbitUrl: 'https://blindbit-testnet.bullbitcoin.com',
          electrumUrl: 'ssl://electrum-testnet.bullbitcoin.com:50002',
        ),
        // Regtest URLs come from the running infra at runtime, not from here.
        BitcoinNetwork.regtest => null,
      };
}
