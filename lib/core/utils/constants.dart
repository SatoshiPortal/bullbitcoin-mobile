import 'dart:math';
import 'package:flutter/material.dart';

class Device {
  static late Size screen;

  static void init(BuildContext context) {
    screen = MediaQuery.of(context).size;
  }
}

class SettingsConstants {
  static const telegramSupportLink = 'https://t.me/+gUHV3ZcQ-_RmZDdh';
  static const webSupportLink = 'https://app.bullbitcoin.com/support';
  static const githubSupportLink =
      'https://github.com/SatoshiPortal/bullbitcoin-mobile';
  static const termsAndConditionsLink = 'https://wallet.bullbitcoin.com/terms';
  static const btcMapUrl = 'https://btcmap.org/map';
  static const recoverbullUrl =
      'http://5m7enm5y77tdgmaf3d5xuwa5c7fjma7v5ljtwxu4q5jtq6b5utspmpyd.onion';
}

class ConversionConstants {
  static final satsAmountOfOneBitcoin = BigInt.from(100_000_000);
  static final maxBitcoinAmount = BigInt.from(21_000_000); // 21 million BTC
  static final maxSatsAmount = maxBitcoinAmount * satsAmountOfOneBitcoin;
}

class SecureStorageKeyPrefixConstants {
  static const seed = 'seed_';
  static const swap = 'swap_';
  static const swapMasterKey = 'swap_master_key_';
  // Fresh key (the old `swap_key_index_` was seeded high by a now-removed bug);
  // this resets the per-network swap index counter to 0.
  static const swapKeyIndex = 'swap_master_key_index_';
}

class HiveBoxNameConstants {
  static const settings = 'settings';
  static const electrumServers = 'electrumServers';
  static const walletMetadata = 'walletMetadata';
  static const pdkPayjoins = 'pdkPayjoins';
  static const boltzSwaps = 'boltzSwaps';
  static const labels = 'labels';
  static const labelsByRef = 'labelsByRef';
}

class AssetConstants {
  static const lbtcMainnet =
      '6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d';
  static const lbtcTestnet =
      '144c654344aa716d6f3abcc1ca90e5641e4e2a7f633bc09fe3baf64585819a49';
}

class CurrencyConstants {
  /// Currencies supported by [CurrencyBottomSheet]'s flag/name lookup.
  /// Single source of truth for both the pre-init wizard's currency
  /// picker (which has no locator access) and the exchange-rate
  /// datasource's hardcoded fallback (until the API supports
  /// fetching the list dynamically).
  static const List<String> supportedFiat = [
    'USD',
    'CAD',
    'MXN',
    'CRC',
    'EUR',
    'ARS',
    'COP',
  ];
}

class PayjoinConstants {
  // Stable base list (fixed order) so a display surface (the payjoin
  // settings screen) can show a consistent order across rebuilds. Actual
  // network use always goes through [ohttpRelayUrls], which shuffles a COPY
  // of this list on every call (anti-fingerprinting network behaviour,
  // unchanged).
  static const List<String> ohttpRelayUrlsBase = [
    'https://ohttp.achow101.com',
    'https://pj.bobspacebkk.com',
    'https://ohttp.cakewallet.com',
  ];

  static List<String> get ohttpRelayUrls {
    final list = [...ohttpRelayUrlsBase];
    list.shuffle(Random.secure());
    return list;
  }

  static const String directoryUrl = 'https://payjo.in';
  static const directoryPollingInterval = 5;

  // Default payjoin session lifetime, kept at the protocol-conventional 24
  // hours ON PURPOSE. Shortening it was considered as an anti-probing lever
  // (see the receiver-side UTXO probing attack, BIP78) and rejected: the
  // UTXO exposure happens at proposal time, so a shorter session does not
  // reduce that information leak — it only bounds (a) how long a probing
  // sender can cheaply invalidate its own fallback transaction before we
  // broadcast it, and (b) the directory polling budget. See "Payjoin
  // Probing Attacks: Facts, Mitigations, and Why Payjoin Still Wins for
  // Privacy" (payjoin.org blog, 2025-03-31): the effective mitigations are
  // the minimum-receive-amount decline and the fallback broadcast at
  // expiry, both implemented here (see [defaultMinAmountSat] and
  // PayjoinRepositoryImpl). That's also why the setting is user-configurable
  // (bounds below) rather than hardcoded shorter.
  static const defaultExpireAfterSec = 60 * 60 * 24; // 24 hours

  // Bounds for the payjoin session-expiry setting (seconds), enforced in
  // SetPayjoinExpireAfterSecUsecase. Floor of 60s: the payjoin directory's
  // own long-poll hold is ~30s (see PayjoinLocator's receiveTimeout
  // comment), so a shorter session couldn't survive even one full poll
  // cycle. Ceiling: the protocol-conventional 24h default above — anything
  // longer only extends the polling budget and the fallback-invalidation
  // window discussed above for no privacy benefit.
  static const int minExpireAfterSec = 60;
  static const int maxExpireAfterSec = 60 * 60 * 24;

  // Single source of truth for the payjoin minimum-receive-amount default:
  // the anti-probing threshold below which an incoming payjoin is declined
  // and the payment falls back to a plain broadcast of the original
  // transaction (see PayjoinRepositoryImpl's below-minimum decline path).
  // This is the "minimum-value policy" recommended by the payjoin.org
  // article referenced above: probing a receiver's UTXO set must cost the
  // prober at least a real payment above this threshold. Referenced by the
  // settings entity default, the DB seed, and the settings table column
  // default; the column default must be kept in sync by hand (drift
  // codegen requires a literal there, see settings_table.dart).
  static const int defaultMinAmountSat = 10000;

  // Bounds for the minimum-receive-amount setting, enforced in
  // SetPayjoinMinAmountUsecase (the UI validates too, but the domain has the
  // final say — a lesson from reviewing a prior draft of this feature where
  // only the UI clamped the value). minMinAmountSat (1000 sats) is just
  // above dust, effectively "always payjoin"; maxMinAmountSat
  // (21_000_000 sats, 0.21 BTC) is a deliberately high "only large amounts"
  // ceiling.
  static const int minMinAmountSat = 1000;
  static const int maxMinAmountSat = 21000000;

  // Receiver-side bound on how much of OUR OWN money a payjoin sender can
  // push into miner fees. In payjoin 1.0.0-rc.5 the receiver's mandatory
  // contribution is (contributed input weight + contributed output weight) x
  // max(BROADCAST_MIN, sender's minfeerate) debited from our change output,
  // and it is rejected only when it exceeds contributed weight x
  // maxEffectiveFeeRate (calculate_psbt_with_fee_range, receive/common).
  // The sender's minfeerate is attacker-controlled, so maxEffectiveFeeRate is
  // the only thing bounding the burn: at the previous hardcoded 10,000 sat/vB
  // a ~100 vB contribution could cost the receiver ~1,000,000 sats.
  //
  // Do NOT "fix" this by also passing a minFeeRate: the crate takes
  // max(ourMinFeeRate, senderMinFeeRate), so a floor of ours can only raise
  // the receiver's contribution, never lower it.
  //
  // The cap is derived per session from the live fastest tier rather than
  // hardcoded, because a fixed number is either too tight in a congested
  // mempool (legitimate payjoins fail and fall back to a plain payment) or
  // too loose in a quiet one. The multiplier is the headroom for the mempool
  // moving between session creation and the request actually arriving, which
  // can be up to defaultExpireAfterSec later.
  static const int maxFeeRateMultiplier = 3;

  // Floor so a near-empty mempool doesn't produce a cap so tight that normal
  // payjoins fail, and hard ceiling so the cap stays bounded no matter what
  // the fee source reports — the mempool server is user-configurable, so it
  // is not fully trusted input. At the ceiling the worst case is ~100 vB x
  // 100 sat/vB = ~10,000 sats instead of ~1,000,000.
  static const int minMaxFeeRateSatPerVb = 20;
  static const int maxMaxFeeRateSatPerVb = 100;
}

class ApiServiceConstants {
  // Bitcoin mempool
  static const bbMempoolUrlPath = 'mempool.bullbitcoin.com';
  static const publicMempoolUrlPath = 'mempool.space'; // note: not used
  static const testnetMempoolUrlPath = 'mempool.space/testnet';

  // Mempool fee endpoints. The precise endpoint returns sub-1 sat/vByte
  // rates as decimals (rounded to 0.001 by mempool); the recommended one
  // returns rounded integers and is only used as a fallback for older
  // self-hosted servers that don't expose the precise route.
  static const mempoolPreciseFeesPath = '/api/v1/fees/precise';
  static const mempoolRecommendedFeesPath = '/api/v1/fees/recommended';

  // Liquid mempool
  static const bbLiquidMempoolUrlPath = 'liquid.bullbitcoin.com';
  static const bbLiquidMempoolTestnetUrlPath = 'liquid.bullbitcoin.com/testnet';
  static const publicLiquidMempoolUrl =
      'https://liquid.network'; // note: not used
  static const publicLiquidMempoolTestnetUrl =
      'https://liquid.network/testnet'; // note: not used

  // Bitcoin Electrum servers
  static const fulcrumElectrumUrl = 'ssl://fulcrum.bullbitcoin.com:50002';
  static const bbElectrumUrl = 'ssl://wes.bullbitcoin.com:50002';
  static const publicElectrumUrl = 'ssl://blockstream.info:700';
  // BB test currently not operational
  static const bbElectrumTestUrl = 'ssl://wes.bullbitcoin.com:60002';
  static const publicElectrumTestUrl = 'ssl://blockstream.info:993';

  // Liquid Electrum servers - lwk does not accept ssl:// prefix
  static const bbLiquidElectrumUrlPath = 'les.bullbitcoin.com:995';
  static const bbLiquidElectrumTestUrlPath = 'les.bullbitcoin.com:465';
  static const publicLiquidElectrumUrlPath = 'blockstream.info:995';
  static const publicliquidElectrumTestUrlPath = 'blockstream.info:465';

  // Boltz API
  static const boltzMainnetUrlPath = 'api.boltz.exchange/v2';
  static const boltzReferralId = 'BULL';

  // BullBitcoin API
  static const String bbApiUrl = 'https://api.bullbitcoin.com';
  static const String bbApiTestUrl = 'https://api05.bullbitcoin.dev';
  static const String bbAuthUrl = 'https://accounts.bullbitcoin.com';
  static const String bbAuthTestUrl = 'https://accounts05.bullbitcoin.dev';
  static const String bbAppUrl = 'https://app.bullbitcoin.com';
  static const String bbKycUrl = 'https://app.bullbitcoin.com/kyc';
  static const String bbKycTestUrl = 'https://bbx05.bullbitcoin.dev/kyc';
  static const String googleDriveClientId =
      '97584343569-0mc4e5q9q1qino4vvo97mqomdi89sae5.apps.googleusercontent.com';

  // Error reports
  static const String sentryDsn =
      'https://b6a8d5134da043eda72f231891c6e51a@cc.bullbitcoin.com/1';
}

class LocatorInstanceNameConstants {
  static const secureStorageDatasource = 'secureStorageDatasource';
  static const boltzSwapsHiveStorageDatasourceInstanceName =
      'boltzSwapsHiveStorageDatasource';
  static const boltzSwapRepositoryInstanceName = 'boltzSwapRepository';
  static const boltzSwapWatcherInstanceName = 'boltzSwapWatcher';
  static const boltzAutoSwapTimerInstanceName = 'boltzAutoSwapTimer';
  static const String labelsHiveStorageDatasourceInstanceName =
      'labelsHiveStorageDatasource';
  static const String labelByRefHiveStorageDatasourceInstanceName =
      'labelByRefHiveStorageDatasource';
  static const String lwkLiquidBlockchainDatasourceInstanceName =
      'lwkLiquidBlockchainDatasourceInstanceName';
  static const String bdkBitcoinBlockchainDatasourceInstanceName =
      'bdkBitcoinBlockchainDatasourceInstanceName';
  static const String bullBitcoinAPIKeyDatasourceInstanceName =
      'bullBitcoinAPIKeyDatasourceInstanceName';
}

class LabelConstants {
  static const separator = '␟';
  static const labelKeyPrefix = 'label';
}

class ExchangeKycConstants {
  /// Maximum CAD transaction amount for Limited Identity Verification users.
  static const double cadLimitedKycMaxAmount = 999.0;

  /// Maximum CAD transaction amount for Canada Light Verification users.
  static const double cadLightKycMaxAmount = 3000.0;
}

class CountryConstants {
  // Better to make this a map to fetch by code directly instead of needing a where
  // clause each time. But for now keeping it as is since best would be to get
  // this from an external API or package anyway in the future.
  static const List<Map<String, String>> countries = [
    {'code': 'US', 'name': 'United States', 'flag': '🇺🇸'},
    {'code': 'CA', 'name': 'Canada', 'flag': '🇨🇦'},
    {'code': 'EU', 'name': 'Europe', 'flag': '🇪🇺'},
    {'code': 'MX', 'name': 'Mexico', 'flag': '🇲🇽'},
    {'code': 'CR', 'name': 'Costa Rica', 'flag': '🇨🇷'},
    {'code': 'AR', 'name': 'Argentina', 'flag': '🇦🇷'},
    {'code': 'CO', 'name': 'Colombia', 'flag': '🇨🇴'},
  ];
}
