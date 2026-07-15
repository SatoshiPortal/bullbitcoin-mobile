import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';

/// Get Paid's narrow wrapper over the invoices public boundary. Presentation
/// receives only an attention count; authenticated rows and protocol details
/// remain owned by the invoices feature.
class GetPaidFallbackAttentionUsecase {
  final InvoicesFacade _invoices;

  const GetPaidFallbackAttentionUsecase({required this._invoices});

  Future<int?> execute() async {
    return switch (await _invoices.fallbackSupervision()) {
      Ok(:final value) => value.attentionCount,
      Err() => null,
    };
  }
}
