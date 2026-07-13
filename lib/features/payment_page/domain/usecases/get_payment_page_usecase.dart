import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_error.dart';

/// Unsigned public GET of the Donation Page row (kind pinned to payment_page).
class GetPaymentPageUsecase {
  final BullnymFacade _bullnym;

  const GetPaymentPageUsecase(this._bullnym);

  Future<PaymentPage> execute({required String nym}) async {
    try {
      final result = await _bullnym.getDonationPage(
        nym: nym,
        kind: bullnymDonationPageKindPaymentPage,
      );
      return switch (result) {
        Ok(:final value) => PaymentPage.fromBullnym(value),
        Err(:final failure) => throw PaymentPageException.fromBullnym(failure),
      };
    } on PaymentPageException {
      rethrow;
    } catch (_) {
      throw const PaymentPageException.unexpected();
    }
  }
}
