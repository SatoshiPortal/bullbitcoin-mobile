import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_error.dart';
import 'package:flutter/widgets.dart';

/// Maps any error surfaced by the invoices facade to friendly, localized copy.
/// A typed [InvoicesException] uses its own `toTranslated`; anything else is
/// logged (diagnostics stay in the log, never in the UI) and shown as generic
/// copy — a raw `toString()` never reaches the screen (charter C3).
String invoiceErrorMessage(BuildContext context, Object error) {
  if (error is InvoicesException) {
    return error.toTranslated(context);
  }
  log.warning('Unexpected invoices error surfaced to UI', error: error);
  return const InvoicesException.unexpected().toTranslated(context);
}
