import 'package:meta/meta.dart';
import 'package:bb_mobile/features/wallet/public/payment_destination.dart';

/// Resolves an external Buy payout without accepting another payment rail.
class ValidateBuyDestinationUsecase {
  final WalletPaymentDestinationFacade _destinations;

  ValidateBuyDestinationUsecase({WalletPaymentDestinationFacade? destinations})
    : _destinations = destinations ?? const WalletPaymentDestinationFacade();

  @useResult
  Future<String?> execute(String input) async => (await _destinations.validate(
    input,
    allowRegtest: false,
    acceptedTypes: const {PaymentDestinationType.bitcoin},
  ))?.address;
}
