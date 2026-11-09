import 'package:bb_mobile/core/errors/send_errors.dart';

/// Diagnostic categories only: never use them to decide whether to retry a payment.
enum BroadcastFailureCategory {
  rejected,
  connection,
  unexpected,
  authorization;

  static BroadcastFailureCategory of(Object error) =>
      error is CategorizedBroadcastException
      ? error.category
      : BroadcastFailureCategory.unexpected;
}

/// Compatibility with existing Send callers, without retaining a foreign cause.
/// A Result-based broadcast capability can replace this legacy exception contract separately; existing catches and localized messages remain unchanged here.
final class CategorizedBroadcastException
    extends BroadcastTransactionException {
  final BroadcastFailureCategory category;

  CategorizedBroadcastException(this.category)
    : super('send_broadcast_failed category=${category.name}');
}
