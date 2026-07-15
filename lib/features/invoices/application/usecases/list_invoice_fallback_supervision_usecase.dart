import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_identity_port.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_pay_service_port.dart';
import 'package:bb_mobile/features/invoices/domain/entities/invoice_fallback_supervision.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_failure.dart';
import 'package:meta/meta.dart';

/// Resolves the merchant signer and reads the server-authoritative automatic
/// fallback projection. It never derives an incident address or sends a
/// mutation.
class ListInvoiceFallbackSupervisionUsecase {
  final InvoicesIdentityPort _identity;
  final InvoicesPayServicePort _payService;

  const ListInvoiceFallbackSupervisionUsecase({
    required this._identity,
    required this._payService,
  });

  @useResult
  Future<Result<InvoiceFallbackOverview, InvoicesFailure>> execute() async {
    return switch (await _identity.getSigningHandle()) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => _payService.listFallbackSupervision(signer: value),
    };
  }
}
