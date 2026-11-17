import '../domain/payment_destination.dart';
import '../domain/validate_payment_destination_usecase.dart';

export '../domain/payment_destination.dart';
export '../ui/widgets/address_viewer.dart' show AddressViewer;
export '../ui/widgets/full_screen_scanner_page.dart';
export '../ui/widgets/payment_destination_field.dart'
    show PaymentDestinationField;

/// Shared destination validation; never resolves an invoice or sends funds.
final class WalletPaymentDestinationFacade {
  const WalletPaymentDestinationFacade();

  Future<PaymentDestination?> validate(
    String raw, {
    required Set<PaymentDestinationType> acceptedTypes,
    bool allowLnurl = true,
  }) => const ValidatePaymentDestinationUsecase().execute(
    raw,
    acceptedTypes: acceptedTypes,
    allowLnurl: allowLnurl,
  );
}
