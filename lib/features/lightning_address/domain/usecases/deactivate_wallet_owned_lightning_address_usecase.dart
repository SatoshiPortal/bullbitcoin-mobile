import 'package:bb_mobile/features/lightning_address/domain/lightning_address_default_wallet_xprv_port.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_nym_validation.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/delete_lightning_address_registration_usecase.dart';

class DeactivateWalletOwnedLightningAddressUsecase {
  final LightningAddressDefaultWalletXprvPort _defaultWalletXprv;
  final DeleteLightningAddressRegistrationUsecase _delete;

  const DeactivateWalletOwnedLightningAddressUsecase({
    required this._defaultWalletXprv,
    required this._delete,
  });

  Future<void> execute({required String nym}) async {
    final normalizedNym = validateLightningAddressNym(nym);
    final xprvBase58 = await _deriveDefaultWalletXprv();
    await _delete.execute(xprvBase58: xprvBase58, nym: normalizedNym);
  }

  Future<String> _deriveDefaultWalletXprv() async {
    try {
      return await _defaultWalletXprv.deriveDefaultWalletXprv();
    } on LightningAddressException {
      rethrow;
    } catch (error) {
      throw LightningAddressException.localPreparationFailed(
        code: error.runtimeType.toString(),
        retryable: true,
      );
    }
  }
}
