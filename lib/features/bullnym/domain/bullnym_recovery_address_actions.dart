import 'package:bb_mobile/features/bullnym/domain/bullnym_recovery_address.dart';

// Deployed identity-wide actions for the private recovery-address contract.
// Both use an empty nym slot. Registration signs [version, btc_address] in
// this exact order; lookup has no payload fields.
const String bullpayActionRecoveryAddressSet = 'recovery-address-set';
const String bullpayActionRecoveryAddressGet = 'recovery-address-get';

List<String> buildRecoveryAddressRegistrationPayloadFields(String btcAddress) {
  return [bullnymRecoveryAddressContractVersion.toString(), btcAddress];
}

List<String> buildRecoveryAddressLookupPayloadFields() => const [];
