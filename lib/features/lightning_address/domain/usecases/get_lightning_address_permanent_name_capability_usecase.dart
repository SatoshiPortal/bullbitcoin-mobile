import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lightning_address_error_mapping.dart';

class GetLightningAddressPermanentNameCapabilityUsecase {
  final BullnymFacade _bullnym;

  const GetLightningAddressPermanentNameCapabilityUsecase(this._bullnym);

  Future<bool> execute() async {
    try {
      return switch (await _bullnym.getVersion()) {
        Ok(:final value) => value.supportsPermanentNamesV1,
        Err(:final failure) => throw mapBullnymToLightningAddressException(
          failure,
        ),
      };
    } on LightningAddressException {
      rethrow;
    } catch (_) {
      throw const LightningAddressException.unexpected();
    }
  }
}
