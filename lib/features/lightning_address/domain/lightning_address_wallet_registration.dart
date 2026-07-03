import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';

class WalletOwnedLightningAddressRegistration {
  final LightningAddressRegistration registration;
  final String walletId;
  final bool walletCreated;

  const WalletOwnedLightningAddressRegistration({
    required this.registration,
    required this.walletId,
    required this.walletCreated,
  });
}
