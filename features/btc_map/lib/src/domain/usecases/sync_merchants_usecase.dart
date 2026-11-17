import 'package:bull_logger/bull_logger.dart';

import '../bull_map_failure.dart';
import '../entities/merchant.dart';
import '../merchant_repository.dart';

import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Brings the device's merchants up to date with BTC Map.
class SyncMerchantsUsecase {
  final MerchantsReader _syncMerchants;

  const SyncMerchantsUsecase(this._syncMerchants);

  @useResult
  Future<Result<List<Merchant>, BullMapFailure>> execute() async {
    final result = await _syncMerchants();
    switch (result) {
      case Ok(value: final merchants):
        log.fine('BTC Map sync: ${merchants.length} places');
      case Err(failure: final failure):
        log.warning(
          'BTC Map sync failed: ${failure.runtimeType} ${failure.logMessage}',
        );
    }
    return result;
  }
}
