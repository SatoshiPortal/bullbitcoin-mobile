import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/features/wallet/public/payment_destination.dart';

class ValidateDefaultWalletDestinationUsecase {
  final WalletPaymentDestinationFacade _destinations;

  ValidateDefaultWalletDestinationUsecase({
    WalletPaymentDestinationFacade? destinations,
  }) : _destinations = destinations ?? const WalletPaymentDestinationFacade();

  @useResult
  Future<String?> execute(WalletAddressType type, String input) async =>
      (await _destinations.validate(
        input,
        acceptedTypes: {
          switch (type) {
            WalletAddressType.bitcoin => PaymentDestinationType.bitcoin,
            WalletAddressType.liquid => PaymentDestinationType.liquid,
            WalletAddressType.lightning =>
              PaymentDestinationType.lightningAddress,
          },
        },
      ))?.address;
}
