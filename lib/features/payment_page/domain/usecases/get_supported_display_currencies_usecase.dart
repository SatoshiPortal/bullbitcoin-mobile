import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_error.dart';

/// A display currency the Donation Page can settle its shown amounts in.
class DisplayCurrency {
  final String code;
  final int precision;

  const DisplayCurrency({required this.code, required this.precision});
}

/// Fetches the server's live supported-currencies list (§13-DG5). No caching:
/// the editor fetches on load so the list can never drift from the server's
/// pricer (the prototype's hardcoded-INR bug class).
class GetSupportedDisplayCurrenciesUsecase {
  final BullnymFacade _bullnym;

  const GetSupportedDisplayCurrenciesUsecase(this._bullnym);

  Future<List<DisplayCurrency>> execute() async {
    try {
      final response = await _bullnym.getSupportedCurrencies();
      return response.currencies
          .map((c) => DisplayCurrency(code: c.code, precision: c.precision))
          .toList();
    } on BullnymException catch (e) {
      throw PaymentPageException.fromBullnym(e);
    } catch (_) {
      throw const PaymentPageException.unexpected();
    }
  }
}
