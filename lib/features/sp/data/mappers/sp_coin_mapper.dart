import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bull_sdk/bwk.dart' as bwk;
import 'package:primitives/primitives.dart';

/// Maps the bwk FFI `UnifiedCoinView`/`CoinSource` into the domain [SpCoin].
abstract final class SpCoinMapper {
  /// bwk reports an outpoint as `"<txid>:<vout>"`. Parsed here so nothing above
  /// the data layer has to split the string.
  static Outpoint parseOutpoint(String raw) {
    final separator = raw.lastIndexOf(':');
    if (separator < 0) {
      throw FormatException('SP outpoint has no vout separator', raw);
    }
    final vout = int.tryParse(raw.substring(separator + 1));
    if (vout == null) {
      throw FormatException('SP outpoint has a non-numeric vout', raw);
    }
    return (txId: raw.substring(0, separator), vout: vout);
  }

  static SpCoin toDomain(bwk.UnifiedCoinView view) => SpCoin(
    source: sourceToDomain(view.source),
    outpoint: parseOutpoint(view.outpoint),
    amountSat: Sats(view.amountSat),
    height: view.height,
    status: switch (view.status) {
      bwk.UnifiedCoinStatus.unconfirmed => SpCoinStatus.unconfirmed,
      bwk.UnifiedCoinStatus.unspent => SpCoinStatus.unspent,
      bwk.UnifiedCoinStatus.spent => SpCoinStatus.spent,
    },
  );

  static SpCoinSource sourceToDomain(bwk.CoinSource source) => switch (source) {
    bwk.CoinSource.sp => SpCoinSource.sp,
    bwk.CoinSource.segwit => SpCoinSource.segwit,
    bwk.CoinSource.taproot => SpCoinSource.taproot,
    bwk.CoinSource.other => SpCoinSource.other,
  };
}
