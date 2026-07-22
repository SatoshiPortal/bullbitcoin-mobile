import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bull_sdk/bwk.dart' as bwk;

/// Maps the bwk FFI `UnifiedCoinView`/`CoinSource` into the domain [SpCoin].
abstract final class SpCoinMapper {
  static SpCoin toDomain(bwk.UnifiedCoinView view) => SpCoin(
    source: sourceToDomain(view.source),
    outpoint: view.outpoint,
    amountSat: view.amountSat,
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
