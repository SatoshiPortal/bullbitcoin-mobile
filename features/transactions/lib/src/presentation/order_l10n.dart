import 'package:exchange/exchange.dart';
import 'package:transactions/src/presentation/transactions_localizations_x.dart';
import 'package:flutter/widgets.dart';

/// User-facing name of an exchange order's type.
extension OrderTypeL10n on Order {
  String typeLabel(BuildContext context) => switch (orderType) {
    OrderType.buy => context.loc.buyTitle,
    OrderType.sell => context.loc.sellTitle,
    OrderType.sellUsdt => context.loc.transactionOrderTypeSellUsdt,
    OrderType.fiatPayment => context.loc.transactionOrderTypeFiatPayment,
    OrderType.funding => context.loc.transactionFilterFunding,
    OrderType.withdraw => context.loc.transactionFilterWithdraw,
    OrderType.reward => context.loc.transactionFilterReward,
    OrderType.refund => context.loc.transactionFilterRefund,
    OrderType.balanceAdjustment =>
      context.loc.transactionOrderTypeBalanceAdjustment,
    // A type added server-side after this build: show the server's name.
    OrderType.unknown => switch (this) {
      final GenericOrder order => order.orderTypeName,
      _ => orderType.value,
    },
  };
}

extension OrderStatusL10n on OrderStatus {
  String toTranslated(BuildContext context) => switch (this) {
    OrderStatus.canceled => context.loc.coreSwapsStatusCanceled,
    OrderStatus.expired => context.loc.coreSwapsStatusPaymentDeadlineExpired,
    OrderStatus.orderExpired => context.loc.coreSwapsStatusExpired,
    OrderStatus.inProgress => context.loc.coreSwapsStatusInProgress,
    OrderStatus.awaitingConfirmation =>
      context.loc.coreSwapsStatusAwaitingConfirmation,
    OrderStatus.completed => context.loc.coreSwapsStatusCompleted,
    OrderStatus.rejected => context.loc.coreSwapsStatusRejected,
    OrderStatus.failed => context.loc.coreSwapsStatusFailed,
    OrderStatus.unknown => context.loc.coreSwapsStatusUnknown,
  };
}

extension OrderPayinStatusL10n on OrderPayinStatus {
  String toTranslated(BuildContext context) => switch (this) {
    OrderPayinStatus.notStarted => context.loc.coreSwapsStatusNotStarted,
    OrderPayinStatus.awaitingPayment =>
      context.loc.coreSwapsStatusAwaitingPayment,
    OrderPayinStatus.inProgress => context.loc.coreSwapsStatusInProgress,
    OrderPayinStatus.underReview => context.loc.coreSwapsStatusUnderReview,
    OrderPayinStatus.awaitingConfirmation =>
      context.loc.coreSwapsStatusAwaitingConfirmation,
    OrderPayinStatus.completed => context.loc.coreSwapsStatusCompleted,
    OrderPayinStatus.rejected => context.loc.coreSwapsStatusRejected,
    OrderPayinStatus.unknown => context.loc.coreSwapsStatusUnknown,
  };
}

extension OrderPayoutStatusL10n on OrderPayoutStatus {
  String toTranslated(BuildContext context) => switch (this) {
    OrderPayoutStatus.notStarted => context.loc.coreSwapsStatusNotStarted,
    OrderPayoutStatus.inProgress => context.loc.coreSwapsStatusInProgress,
    OrderPayoutStatus.scheduled => context.loc.coreSwapsStatusScheduled,
    OrderPayoutStatus.awaitingClaim => context.loc.coreSwapsStatusAwaitingClaim,
    OrderPayoutStatus.completed => context.loc.coreSwapsStatusCompleted,
    OrderPayoutStatus.canceled => context.loc.coreSwapsStatusCanceled,
    OrderPayoutStatus.failed => context.loc.coreSwapsStatusFailed,
    OrderPayoutStatus.unknown => context.loc.coreSwapsStatusUnknown,
  };
}
