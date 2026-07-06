import 'package:bb_mobile/features/payment_page/domain/payment_page.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_liveness.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_validation.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/get_supported_display_currencies_usecase.dart';

export 'package:bb_mobile/features/payment_page/domain/payment_page.dart';
export 'package:bb_mobile/features/payment_page/domain/payment_page_error.dart';
export 'package:bb_mobile/features/payment_page/domain/payment_page_liveness.dart';
export 'package:bb_mobile/features/payment_page/domain/payment_page_validation.dart';
export 'package:bb_mobile/features/payment_page/domain/usecases/get_supported_display_currencies_usecase.dart'
    show DisplayCurrency;

/// Cross-feature contract for the Donation Page product. Callback-injection
/// shape (the Lightning Address facade precedent): the locator wires each
/// callback to its usecase, keeping the feature's usecases and ports internal.
class PaymentPageFacade {
  final Future<PaymentPage?> Function({required String nym}) _findCallback;
  final Future<PaymentPage> Function(SavePaymentPageCommand command)
  _saveCallback;
  final Future<PaymentPage?> Function() _archiveCallback;
  final Future<List<DisplayCurrency>> Function() _supportedCurrenciesCallback;
  final Future<PaymentPageHealOutcome> Function() _ensurePageLiveCallback;

  const PaymentPageFacade({
    required Future<PaymentPage?> Function({required String nym}) find,
    required Future<PaymentPage> Function(SavePaymentPageCommand command) save,
    required Future<PaymentPage?> Function() archive,
    required Future<List<DisplayCurrency>> Function() supportedCurrencies,
    required Future<PaymentPageHealOutcome> Function() ensurePageLive,
  }) : _findCallback = find,
       _saveCallback = save,
       _archiveCallback = archive,
       _supportedCurrenciesCallback = supportedCurrencies,
       _ensurePageLiveCallback = ensurePageLive;

  /// Probe the current page row for `nym`; null when no page exists yet.
  Future<PaymentPage?> find({required String nym}) => _findCallback(nym: nym);

  Future<PaymentPage> save(SavePaymentPageCommand command) =>
      _saveCallback(command);

  /// Archive ("deactivate") the page; null when already archived / absent.
  Future<PaymentPage?> archive() => _archiveCallback();

  Future<List<DisplayCurrency>> supportedCurrencies() =>
      _supportedCurrenciesCallback();

  /// DG-3 recovery heal — READ-ONLY liveness classification, never a write.
  Future<PaymentPageHealOutcome> ensurePageLive() => _ensurePageLiveCallback();
}
