import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'bull_map_failure.dart';
import 'entities/merchant.dart';

/// The shape of `BullMapSession.cachedMerchants` and `syncMerchants`, for code
/// that takes them as a dependency so tests can replace them.
typedef MerchantsReader =
    Future<Result<List<Merchant>, BullMapFailure>> Function();

abstract interface class MerchantRepository {
  @useResult
  Future<Result<List<Merchant>, BullMapFailure>> cached();

  @useResult
  Future<Result<List<Merchant>, BullMapFailure>> sync();
}
