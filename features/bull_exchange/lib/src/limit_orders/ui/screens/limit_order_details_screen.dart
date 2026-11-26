import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_cancel.dart';
import 'package:bull_exchange/src/limit_orders/presentation/limit_order_details_bloc.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_details_flow.dart';
import 'package:bull_exchange/src/limit_orders/ui/widgets/limit_order_detail_row.dart';
import 'package:bull_exchange/src/limit_orders/ui/widgets/limit_orders_loading_bar.dart';
import 'package:bull_exchange/src/steps_l10n.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show FormatAmount;

/// The details of one limit order, built from [LimitDetailsState]; Back is
/// an event, and leaving answers whether the order changed.
final class LimitOrderDetailsScreen extends StatelessWidget {
  const LimitOrderDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LimitDetailsBloc, LimitDetailsState>(
      listenWhen: (previous, current) =>
          current is DetailsClosed && previous is! DetailsClosed,
      listener: (context, state) {
        if (state case DetailsClosed(:final changed)) {
          if (context.canPop()) context.pop(changed);
        }
      },
      builder: (context, state) {
        final bloc = context.read<LimitDetailsBloc>();
        return PopScope(
          canPop: state is DetailsClosed,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) bloc.add(const DetailsBackPressed());
          },
          child: limitDetailsPageFor(context, state, bloc.add),
        );
      },
    );
  }
}

/// The page of [state].
Widget limitDetailsPageFor(
  BuildContext context,
  LimitDetailsState state,
  void Function(LimitDetailsEvent event) onEvent,
) {
  final busy = switch (state) {
    DetailsLoading() => true,
    DetailsShown(:final cancel) => limitCancelRunning(cancel),
    DetailsFailed() || DetailsSessionEnded() || DetailsClosed() => false,
  };
  final (Widget body, Widget? bottom) = switch (state) {
    DetailsLoading() || DetailsClosed() => (const SizedBox.shrink(), null),
    DetailsFailed(:final problem) => (
      _Message(
        message: switch (problem) {
          ReadProblemMissing() => context.loc.limitOrderNotFoundError,
          ReadProblemUnreachable() ||
          ReadProblemMalformed() => context.loc.limitOrdersLoadError,
        },
        action: context.loc.retry,
        onPressed: () => onEvent(const DetailsRetryPressed()),
      ),
      null,
    ),
    DetailsSessionEnded() => (
      _Message(
        message: context.loc.exchangeFlowSessionEnded,
        action: context.loc.closeDialogButton,
        onPressed: () => onEvent(const DetailsBackPressed()),
      ),
      null,
    ),
    DetailsShown(:final cancel) => (
      _Details(cancel: cancel),
      _bottom(context, cancel, onEvent),
    ),
  };
  return BullScaffold(
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          BullTopBar(
            title: context.loc.limitOrderDetailsTitle,
            onBack: () => onEvent(const DetailsBackPressed()),
          ),
          SizedBox(
            height: 3,
            child: busy ? const LimitOrdersLoadingBar() : null,
          ),
          Expanded(child: body),
        ],
      ),
    ),
    bottomNavigationBar: bottom == null
        ? null
        : SafeArea(
            top: false,
            child: Padding(padding: const EdgeInsets.all(16), child: bottom),
          ),
  );
}

Widget _bottom(
  BuildContext context,
  LimitCancelState cancel,
  void Function(LimitDetailsEvent event) onEvent,
) {
  final done = BullButton.secondary(
    label: context.loc.limitOrdersDone,
    onPressed: () => onEvent(const DetailsBackPressed()),
  );
  return switch (cancel) {
    CancelIdle(:final order) when order.isActive => BullButton.primary(
      label: context.loc.limitOrderCancel,
      onPressed: () => _confirmCancel(context, onEvent),
    ),
    CancelSending() || CancelChecking() => BullButton.primary(
      label: context.loc.limitOrderCancel,
      onPressed: null,
    ),
    CancelUnverified() => BullButton.primary(
      label: context.loc.exchangeStepCheckAgain,
      onPressed: () => onEvent(const DetailsRetryPressed()),
    ),
    CancelIdle() || CancelDone() || CancelSessionEnded() => done,
  };
}

Future<void> _confirmCancel(
  BuildContext context,
  void Function(LimitDetailsEvent event) onEvent,
) async {
  final confirmed = await BullDialog.show<bool>(
    context: context,
    builder: (dialogContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.loc.limitOrderCancelTitle, style: context.bullType.title),
        const Gap(BullSpacing.sm),
        Text(context.loc.limitOrderCancelMessage),
        const Gap(BullSpacing.lg),
        BullButton.primary(
          label: context.loc.limitOrdersDialogConfirm,
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
        const Gap(BullSpacing.sm),
        BullButton.secondary(
          label: context.loc.cancel,
          onPressed: () => Navigator.pop(dialogContext, false),
        ),
      ],
    ),
  );
  if (confirmed == true) onEvent(const DetailsCancelChanged(CancelPressed()));
}

final class _Message extends StatelessWidget {
  const _Message({
    required this.message,
    required this.action,
    required this.onPressed,
  });

  final String message;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const Gap(16),
          BullButton.secondary(
            size: BullButtonSize.small,
            label: action,
            onPressed: onPressed,
          ),
        ],
      ),
    ),
  );
}

final class _Details extends StatelessWidget {
  const _Details({required this.cancel});

  final LimitCancelState cancel;

  @override
  Widget build(BuildContext context) {
    final order = cancel.order;
    final dateFormat = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).add_jm();
    final problem = switch (cancel) {
      CancelIdle(problem: CancelGateProblem(:final refusal)) =>
        refusal.toTranslated(context),
      CancelIdle(problem: CancelNotApplied()) =>
        context.loc.limitOrderCancellationError,
      CancelUnverified(:final problem) =>
        '${context.loc.exchangeStepUnverified}\n'
            '${problem.toTranslated(context)}',
      CancelIdle() ||
      CancelSending() ||
      CancelChecking() ||
      CancelDone() ||
      CancelSessionEnded() => null,
    };
    return BullScrollableColumn(
      padding: const EdgeInsets.all(24),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LimitOrderDetailRow(
          label: context.loc.limitOrderDetailsStatus,
          value: limitOrderStatusText(context, order.status),
        ),
        const Divider(),
        LimitOrderDetailRow(
          label: context.loc.limitOrderDetailsNumber,
          value: order.number,
        ),
        const Divider(),
        LimitOrderDetailRow(
          label: context.loc.limitOrdersFiatAmount,
          value: FormatAmount.fiat(order.fiatAmount, order.currencyCode),
        ),
        const Divider(),
        LimitOrderDetailRow(
          label: context.loc.limitOrdersTargetPrice,
          value: FormatAmount.fiat(order.limitPrice, order.currencyCode),
        ),
        const Divider(),
        LimitOrderDetailRow(
          label: context.loc.limitOrdersEstimatedBuyPrice,
          value: order.estimatedBtcAmount > 0
              ? FormatAmount.fiat(
                  order.fiatAmount / order.estimatedBtcAmount,
                  order.currencyCode,
                )
              : '—',
        ),
        const Divider(),
        LimitOrderDetailRow(
          label: context.loc.limitOrderDetailsEstimatedBitcoin,
          value: FormatAmount.btc(order.estimatedBtcAmount),
        ),
        const Divider(),
        LimitOrderDetailRow(
          label: context.loc.limitOrderDetailsAddress,
          value: order.address,
        ),
        const Divider(),
        LimitOrderDetailRow(
          label: context.loc.limitOrderDetailsCreated,
          value: dateFormat.format(order.createdAt.toLocal()),
        ),
        const Divider(),
        LimitOrderDetailRow(
          label: context.loc.limitOrderDetailsExpires,
          value: dateFormat.format(order.expiresAt.toLocal()),
        ),
        if (problem != null) ...[
          const Gap(12),
          Text(problem, style: TextStyle(color: context.bull.error)),
        ],
      ],
    );
  }
}

String limitOrderStatusText(BuildContext context, LimitOrderStatus status) =>
    switch (status) {
      LimitOrderStatus.active => context.loc.limitOrderStatusActive,
      LimitOrderStatus.executed => context.loc.limitOrderStatusExecuted,
      LimitOrderStatus.cancelled => context.loc.limitOrderStatusCancelled,
      LimitOrderStatus.expired => context.loc.limitOrderStatusExpired,
      LimitOrderStatus.failed => context.loc.limitOrderStatusFailed,
      LimitOrderStatus.unknown => context.loc.limitOrderStatusUnknown,
    };
