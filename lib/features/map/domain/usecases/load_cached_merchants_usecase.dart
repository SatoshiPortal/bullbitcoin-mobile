import 'package:bull_map/bull_map.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The merchants already on the device, shown before any network answer.
class LoadCachedMerchantsUsecase {
  final MerchantsReader _cachedMerchants;

  const LoadCachedMerchantsUsecase(this._cachedMerchants);

  @useResult
  Future<Result<List<Merchant>, BullMapFailure>> execute() =>
      _cachedMerchants();
}
