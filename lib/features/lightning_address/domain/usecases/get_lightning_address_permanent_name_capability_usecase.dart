import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_failure.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lightning_address_failure_mapping.dart';

class GetLightningAddressPermanentNameCapabilityUsecase {
  final BullnymFacade _bullnym;

  const GetLightningAddressPermanentNameCapabilityUsecase(this._bullnym);

  Future<Result<bool, LightningAddressFailure>> execute() async =>
      switch (await _bullnym.getVersion()) {
        Ok(:final value) => Ok(value.supportsPermanentNamesV1),
        Err(:final failure) => Err(
          mapBullnymToLightningAddressFailure(failure),
        ),
      };
}
