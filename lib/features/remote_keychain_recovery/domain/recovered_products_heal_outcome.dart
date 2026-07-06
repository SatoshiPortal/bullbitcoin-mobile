import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/payment_page/public/payment_page_facade.dart';

/// The DG-3 auto-heal interpretation for every bullnym-backed product a restore
/// flagged for reactivation. Each product's outcome is independent; a field is
/// null when that product was not flagged (nothing to heal / render).
class RecoveredProductsHealOutcome {
  final LightningAddressHealOutcome? lightningAddress;
  final PaymentPageHealOutcome? paymentPage;

  const RecoveredProductsHealOutcome({this.lightningAddress, this.paymentPage});
}
