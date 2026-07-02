import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

/// Single source of truth for network fee rates. The implementation in
/// `data/` decides where the numbers come from (mempool API for Bitcoin,
/// pinned minrelayfee for Liquid) and maps them to the three preset tiers.
abstract interface class FeesRepository {
  Future<FeeOptions> getNetworkFees({required Network network});
}
