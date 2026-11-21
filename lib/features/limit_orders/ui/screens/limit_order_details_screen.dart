import 'package:primitives/primitives.dart' show FormatAmount;
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order.dart';
import 'package:bb_mobile/features/limit_orders/presentation/limit_order_details_cubit.dart';
import 'package:bb_mobile/features/limit_orders/presentation/limit_order_details_state.dart';
import 'package:bb_mobile/features/limit_orders/presentation/limit_orders_failure_l10n.dart';
import 'package:bb_mobile/features/limit_orders/ui/widgets/limit_order_detail_row.dart';
import 'package:bb_mobile/features/limit_orders/ui/widgets/limit_orders_loading_bar.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

final class LimitOrderDetailsScreen extends StatelessWidget {
  const LimitOrderDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LimitOrderDetailsCubit>().state;
    return BullScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BullTopBar(
              title: context.loc.limitOrderDetailsTitle,
              onBack: context.pop,
            ),
            SizedBox(
              height: 3,
              child: state.isLoading || state.isCancelling
                  ? const LimitOrdersLoadingBar()
                  : null,
            ),
            Expanded(
              child: state.isLoading && state.order == null
                  ? const SizedBox.shrink()
                  : state.order == null
                  ? _error(context, state.failure?.toTranslated(context))
                  : _details(context, state.order!, state.wasCancelled),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _bottomBar(context, state),
    );
  }

  Widget? _bottomBar(BuildContext context, LimitOrderDetailsState state) {
    final order = state.order;
    if (order == null) return null;
    final button = order.isActive && !state.wasCancelled
        ? BullButton.primary(
            label: context.loc.limitOrderCancel,
            onPressed: (state.isCancelling)
                ? null
                : () => _confirmCancel(context),
          )
        : BullButton.secondary(
            label: context.loc.limitOrdersDone,
            onPressed: () => context.pop(state.wasCancelled),
          );
    return SafeArea(
      top: false,
      child: Padding(padding: const EdgeInsets.all(16), child: button),
    );
  }

  Widget _error(BuildContext context, String? message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message ?? context.loc.limitOrdersLoadError),
          const Gap(16),
          BullButton.secondary(
            size: BullButtonSize.small,
            label: context.loc.retry,
            onPressed: context.read<LimitOrderDetailsCubit>().load,
          ),
        ],
      ),
    ),
  );

  Widget _details(BuildContext context, LimitOrder order, bool wasCancelled) {
    final state = context.watch<LimitOrderDetailsCubit>().state;
    final dateFormat = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).add_jm();
    return BullScrollableColumn(
      padding: const EdgeInsets.all(24),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LimitOrderDetailRow(
          label: context.loc.limitOrderDetailsStatus,
          value: _status(context, order.status),
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
        if (state.failure case final failure?) ...[
          const Gap(12),
          Text(
            failure.toTranslated(context),
            style: TextStyle(color: context.bull.error),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await BullDialog.show<bool>(
      context: context,
      builder: (dialogContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.loc.limitOrderCancelTitle,
            style: context.bullType.title,
          ),
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
    if (confirmed == true && context.mounted) {
      await context.read<LimitOrderDetailsCubit>().cancel();
    }
  }

  String _status(BuildContext context, LimitOrderStatus status) =>
      switch (status) {
        LimitOrderStatus.active => context.loc.limitOrderStatusActive,
        LimitOrderStatus.executed => context.loc.limitOrderStatusExecuted,
        LimitOrderStatus.cancelled => context.loc.limitOrderStatusCancelled,
        LimitOrderStatus.expired => context.loc.limitOrderStatusExpired,
        LimitOrderStatus.failed => context.loc.limitOrderStatusFailed,
      };
}
