import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/pos/domain/pos_error.dart';

/// A display currency the Point of Sale can settle its shown amounts in.
class DisplayCurrency {
  final String code;
  final int precision;

  const DisplayCurrency({required this.code, required this.precision});
}

/// Fetches the server's live supported-currencies list (§13-DG-P1). No caching:
/// the screen fetches on load so the list can never drift from the server's
/// pricer. Own copy per feature (the LA/PP precedent - the pos feature does not
/// import the payment_page usecase).
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
      throw PosException.fromBullnym(e);
    } catch (_) {
      throw const PosException.unexpected();
    }
  }
}
