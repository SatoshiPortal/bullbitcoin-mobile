import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';

/// Translates the exchange order status strings carried by an order swap into
/// user-facing labels.
extension OrderSwapStatusL10n on String {
  String toTranslatedOrderStatus(BuildContext context) {
    return switch (_normalized) {
      'not started' => context.loc.coreSwapsStatusNotStarted,
      'in pending' || 'pending' => context.loc.coreSwapsStatusPending,
      'awaiting payment' => context.loc.coreSwapsStatusAwaitingPayment,
      'awaiting confirmation' =>
        context.loc.coreSwapsStatusAwaitingConfirmation,
      'awaiting claim' => context.loc.coreSwapsStatusAwaitingClaim,
      'under review' => context.loc.coreSwapsStatusUnderReview,
      'in progress' => context.loc.coreSwapsStatusInProgress,
      'scheduled' => context.loc.coreSwapsStatusScheduled,
      'completed' => context.loc.coreSwapsStatusCompleted,
      'refunded' => context.loc.coreSwapsStatusRefunded,
      // The API has been seen sending both spellings.
      'canceled' || 'cancelled' => context.loc.coreSwapsStatusCanceled,
      'rejected' => context.loc.coreSwapsStatusRejected,
      'payment deadline expired' =>
        context.loc.coreSwapsStatusPaymentDeadlineExpired,
      'expired' => context.loc.coreSwapsStatusExpired,
      'failed' => context.loc.coreSwapsStatusFailed,
      'unknown' || '' => context.loc.coreSwapsStatusUnknown,
      _ => _humanized,
    };
  }

  String get _normalized => replaceAll('_', ' ').trim().toLowerCase();

  /// `Some_new_code` -> `Some new code`: never show the user a raw wire value.
  String get _humanized {
    final words = _normalized.split(' ').where((w) => w.isNotEmpty);
    if (words.isEmpty) return this;
    final first = words.first;
    return [
      first[0].toUpperCase() + first.substring(1),
      ...words.skip(1),
    ].join(' ');
  }
}
