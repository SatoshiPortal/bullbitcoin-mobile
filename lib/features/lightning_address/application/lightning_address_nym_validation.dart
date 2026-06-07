import 'package:bb_mobile/features/lightning_address/application/application_errors.dart';

void validateLightningAddressNym(String nym) {
  if (nym.trim().isEmpty) {
    throw const LightningAddressException.invalidNym();
  }
}
