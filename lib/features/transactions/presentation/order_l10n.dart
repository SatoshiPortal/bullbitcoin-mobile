import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';

extension OrderTypeL10n on Order {
  /// A type this build does not know shows the name the server sent.
  String typeLabel(BuildContext context) => switch (orderType) {
    OrderType.buy => context.loc.exchangeOrderTypeBuy,
    OrderType.sell => context.loc.exchangeOrderTypeSell,
    OrderType.sellUsdt => context.loc.exchangeOrderTypeSellUsdt,
    OrderType.fiatPayment => context.loc.exchangeOrderTypeFiatPayment,
    OrderType.funding => context.loc.exchangeOrderTypeFunding,
    OrderType.withdraw => context.loc.exchangeOrderTypeWithdraw,
    OrderType.reward => context.loc.exchangeOrderTypeReward,
    OrderType.refund => context.loc.exchangeOrderTypeRefund,
    OrderType.balanceAdjustment =>
      context.loc.exchangeOrderTypeBalanceAdjustment,
    OrderType.unknown => switch (this) {
      final GenericOrder order => order.orderTypeName,
      _ => context.loc.coreSwapsStatusUnknown,
    },
  };
}

extension OrderStatusL10n on OrderStatus {
  String label(BuildContext context) => switch (this) {
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
  String label(BuildContext context) => switch (this) {
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
  String label(BuildContext context) => switch (this) {
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

extension OrderPaymentMethodL10n on OrderPaymentMethod {
  String label(BuildContext context) {
    final loc = context.loc;
    return switch (this) {
      OrderPaymentMethod.eTransfer => loc.exchangeOrderPaymentMethodETransfer,
      OrderPaymentMethod.eTransferArs =>
        loc.exchangeOrderPaymentMethodBankTransferArs,
      OrderPaymentMethod.bankTransferCop =>
        loc.exchangeOrderPaymentMethodBankTransferCop,
      OrderPaymentMethod.billPayment =>
        loc.exchangeOrderPaymentMethodBillPayment,
      OrderPaymentMethod.bankTransfer =>
        loc.exchangeOrderPaymentMethodBankTransfer,
      OrderPaymentMethod.sepa => loc.exchangeOrderPaymentMethodSepa,
      OrderPaymentMethod.ibanCrc => loc.exchangeOrderPaymentMethodIbanCrc,
      OrderPaymentMethod.ibanUsd => loc.exchangeOrderPaymentMethodIbanUsd,
      OrderPaymentMethod.sinpe => loc.exchangeOrderPaymentMethodSinpe,
      OrderPaymentMethod.cadBalance => loc.exchangeOrderPaymentMethodBalance(
        'CAD',
      ),
      OrderPaymentMethod.eurBalance => loc.exchangeOrderPaymentMethodBalance(
        'EUR',
      ),
      OrderPaymentMethod.mxnBalance => loc.exchangeOrderPaymentMethodBalance(
        'MXN',
      ),
      OrderPaymentMethod.arsBalance => loc.exchangeOrderPaymentMethodBalance(
        'ARS',
      ),
      OrderPaymentMethod.copBalance => loc.exchangeOrderPaymentMethodBalance(
        'COP',
      ),
      OrderPaymentMethod.crcBalance => loc.exchangeOrderPaymentMethodBalance(
        'CRC',
      ),
      OrderPaymentMethod.usdBalance => loc.exchangeOrderPaymentMethodBalance(
        'USD',
      ),
      OrderPaymentMethod.bitcoin => loc.exchangeOrderPaymentMethodBitcoin,
      OrderPaymentMethod.liquid => loc.exchangeOrderPaymentMethodLiquid,
      OrderPaymentMethod.lnAddress => loc.exchangeOrderPaymentMethodLnAddress,
      OrderPaymentMethod.lnInvoice => loc.exchangeOrderPaymentMethodLnInvoice,
      OrderPaymentMethod.lnUrl => loc.exchangeOrderPaymentMethodLnUrl,
      OrderPaymentMethod.referralCad => loc.exchangeOrderPaymentMethodReferral(
        'CAD',
      ),
      OrderPaymentMethod.referralEur => loc.exchangeOrderPaymentMethodReferral(
        'EUR',
      ),
      OrderPaymentMethod.referralMxn => loc.exchangeOrderPaymentMethodReferral(
        'MXN',
      ),
      OrderPaymentMethod.referralUsd => loc.exchangeOrderPaymentMethodReferral(
        'USD',
      ),
      OrderPaymentMethod.referralCrc => loc.exchangeOrderPaymentMethodReferral(
        'CRC',
      ),
      OrderPaymentMethod.referralArs => loc.exchangeOrderPaymentMethodReferral(
        'ARS',
      ),
      OrderPaymentMethod.referralCop => loc.exchangeOrderPaymentMethodReferral(
        'COP',
      ),
      OrderPaymentMethod.spei => loc.exchangeOrderPaymentMethodSpei,
      OrderPaymentMethod.thinAir => loc.exchangeOrderPaymentMethodThinAir,
      OrderPaymentMethod.refundCrc => loc.exchangeOrderPaymentMethodRefund(
        'CRC',
      ),
      OrderPaymentMethod.refundUsd => loc.exchangeOrderPaymentMethodRefund(
        'USD',
      ),
      OrderPaymentMethod.loadhub => loc.exchangeOrderPaymentMethodLoadhub,
      OrderPaymentMethod.unknown => loc.exchangeOrderPaymentMethodUnknown,
    };
  }
}
