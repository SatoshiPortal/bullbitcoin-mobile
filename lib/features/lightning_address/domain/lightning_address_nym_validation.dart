import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_failure.dart';

String normalizeLightningAddressNym(String nym) => nym.trim().toLowerCase();

/// Returns the exact normalized nym that is safe to send to Bullnym.
///
/// The shared Bullnym value object is the protocol authority for syntax and
/// reservations. Keeping normalization here lets every Lightning Address
/// caller sign and submit the same bytes the first-claim UI displays.
Result<String, LightningAddressFailure> validateLightningAddressNym(
  String nym,
) {
  final normalized = normalizeLightningAddressNym(nym);
  if (bullnymReservedNyms.contains(normalized)) {
    return const Err(LightningAddressFailure.reservedNym());
  }
  try {
    return Ok(BullnymPublicName.nymClaim(normalized).value);
  } on ArgumentError {
    return const Err(LightningAddressFailure.invalidNym());
  }
}
