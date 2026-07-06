import 'package:bb_mobile/features/payment_page/domain/payment_page.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_error.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/get_payment_page_usecase.dart';

/// A "does a page exist yet?" probe for the editor/status surface: returns null
/// when the server has no page row, and rethrows every other failure (network,
/// unreachable, malformed) so the caller can degrade loudly rather than treat
/// an unreachable server as "no page".
class FindPaymentPageUsecase {
  final GetPaymentPageUsecase _getPage;

  const FindPaymentPageUsecase(this._getPage);

  Future<PaymentPage?> execute({required String nym}) async {
    try {
      return await _getPage.execute(nym: nym);
    } on PaymentPageException catch (e) {
      if (e.kind == PaymentPageErrorKind.notFound) return null;
      rethrow;
    }
  }
}
