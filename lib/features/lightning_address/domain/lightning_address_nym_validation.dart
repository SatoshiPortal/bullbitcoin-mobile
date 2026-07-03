import 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';

void validateLightningAddressNym(String nym) {
  final normalized = nym.trim();
  if (normalized.isEmpty || normalized.contains('@')) {
    throw const LightningAddressException.invalidNym();
  }
}
