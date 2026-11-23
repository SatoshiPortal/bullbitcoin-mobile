import 'package:bb_mobile/features/wallet/domain/payment_destination.dart';
import 'package:bb_mobile/features/wallet/domain/validate_payment_destination_usecase.dart';

export 'package:bb_mobile/features/wallet/domain/payment_destination.dart';
export 'package:bb_mobile/features/wallet/ui/widgets/full_screen_scanner_page.dart';
export 'package:bb_mobile/features/wallet/ui/widgets/payment_destination_field.dart'
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
