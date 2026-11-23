import 'src/domain/payment_destination.dart';
import 'src/domain/validate_payment_destination_usecase.dart';

export 'src/domain/detect_bitcoin_string_usecase.dart'
    show DetectBitcoinStringUsecase;
export 'src/domain/payment_destination.dart';
export 'src/ui/widgets/full_screen_scanner_page.dart';
export 'src/ui/widgets/payment_destination_field.dart'
    show PaymentDestinationField;

/// Shared destination validation; never resolves an invoice or sends funds.
final class PaymentDestinations {
  const PaymentDestinations();

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
