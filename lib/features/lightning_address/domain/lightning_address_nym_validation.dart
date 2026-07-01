import 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';

void validateLightningAddressNym(String nym) {
  if (nym.trim().isEmpty) {
    throw const LightningAddressException.invalidNym();
  }
}
