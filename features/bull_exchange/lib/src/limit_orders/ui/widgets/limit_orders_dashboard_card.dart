import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/limit_orders/limit_orders_navigation.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_orders_list_state.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_orders_list_event.dart';
import 'package:bull_exchange/src/limit_orders/presentation/limit_orders_list_bloc.dart';
import 'package:bull_exchange/src/steps_l10n.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show FormatAmount;

/// The dashboard's limit orders, built from [LimitOrdersListState].
final class LimitOrdersDashboardCard extends StatelessWidget {
  const LimitOrdersDashboardCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LimitOrdersListBloc>().state;
    return BullBorderedTile(
      padding: const EdgeInsets.all(BullSpacing.md),
      backgroundColor: context.bull.surface,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _content(context, state),
      ),
    );
  }

  Widget _content(BuildContext context, LimitOrdersListState state) {
    final bloc = context.read<LimitOrdersListBloc>();
    Widget failed(String message) => Column(
      key: const ValueKey('error'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, style: TextStyle(color: context.bull.error)),
        const Gap(12),
        BullButton.secondary(
          size: BullButtonSize.small,
          label: context.loc.retry,
          onPressed: () => bloc.add(const ListRetryPressed()),
        ),
      ],
    );
    return switch (state) {
      ListLoading() || ListRefreshing(orders: []) => const Column(
        key: ValueKey('loading'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BullShimmerLine(
            height: 16,
            padding: EdgeInsets.symmetric(vertical: 6),
          ),
          BullShimmerLine(
            height: 16,
            width: 180,
            padding: EdgeInsets.symmetric(vertical: 6),
          ),
        ],
      ),
      ListFailed() => failed(context.loc.limitOrdersLoadError),
      ListSignedOut() => failed(context.loc.limitOrdersAccountUnavailableError),
      ListShown(orders: []) || ListCancellingAll(orders: []) => InkWell(
        key: const ValueKey('inactive'),
        onTap: () => _openCreate(context),
        child: Row(
          children: [
            const Icon(Icons.multiline_chart),
            const Gap(12),
            Expanded(
              child: Text(
                context.loc.limitOrdersTitle,
                style: context.bullType.body.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
      ListShown(:final orders, :final problem) => _active(
        context,
        orders,
        problem: problem,
        cancelling: false,
      ),
      ListRefreshing(:final orders) => _active(
        context,
        orders,
        problem: null,
        cancelling: false,
      ),
      ListCancellingAll(:final orders) => _active(
        context,
        orders,
        problem: null,
        cancelling: true,
      ),
    };
  }

  Widget _active(
    BuildContext context,
    List<LimitOrder> orders, {
    required LimitListProblem? problem,
    required bool cancelling,
  }) {
    final canCreate = orders.length < maximumActiveLimitOrders;
    final message = switch (problem) {
      ListRefreshFailed() => context.loc.limitOrdersLoadError,
      ListCancelAllRefused(:final refusal) => refusal.toTranslated(context),
      ListCancelAllNotApplied() => context.loc.limitOrderCancellationError,
      null => null,
    };
    return Column(
      key: const ValueKey('active'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.multiline_chart),
            const Gap(12),
            Expanded(
              child: Text(
                context.loc.limitOrdersActiveTitle,
                style: context.bullType.body.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.circle, size: 10, color: context.bull.primary),
          ],
        ),
        const Gap(12),
        for (final order in orders) ...[
          InkWell(
            onTap: () => _openDetails(context, order.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.loc.limitOrdersBuyAt(
                        FormatAmount.fiat(order.limitPrice, order.currencyCode),
                      ),
                    ),
                  ),
                  Text(FormatAmount.fiat(order.fiatAmount, order.currencyCode)),
                  const Gap(8),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
          const Divider(),
        ],
        if (!canCreate)
          Text(
            context.loc.limitOrdersMaximumActiveHint,
            style: context.bullType.label.copyWith(fontWeight: FontWeight.w400),
          ),
        const Gap(8),
        OverflowBar(
          alignment: MainAxisAlignment.spaceBetween,
          spacing: 8,
          overflowSpacing: 8,
          children: [
            BullButton.secondary(
              label: context.loc.limitOrdersCancelAll,
              onPressed: cancelling ? null : () => _confirmCancelAll(context),
              size: BullButtonSize.small,
              compact: true,
            ),
            if (canCreate)
              BullButton.primary(
                label: context.loc.limitOrdersCreateNew,
                onPressed: () => _openCreate(context),
                size: BullButtonSize.small,
                compact: true,
              ),
          ],
        ),
        if (message != null)
          Text(message, style: TextStyle(color: context.bull.error)),
      ],
    );
  }

  Future<void> _openDetails(BuildContext context, String orderId) async {
    final bloc = context.read<LimitOrdersListBloc>();
    final changed = await LimitOrdersNavigation.openDetails(context, orderId);
    if (changed == true) bloc.add(const ListRefreshRequested());
  }

  Future<void> _openCreate(BuildContext context) async {
    final bloc = context.read<LimitOrdersListBloc>();
    final created = await LimitOrdersNavigation.openCreate(context);
    if (created == null || !context.mounted) return;
    // Opened from here, so a cancel there reloads this list (LIM-5).
    if (created.openDetails) {
      await LimitOrdersNavigation.openDetails(context, created.orderId);
    }
    bloc.add(const ListRefreshRequested());
  }

  Future<void> _confirmCancelAll(BuildContext context) async {
    final bloc = context.read<LimitOrdersListBloc>();
    final confirmed = await BullDialog.show<bool>(
      context: context,
      builder: (dialogContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.loc.limitOrdersCancelAllTitle,
            style: context.bullType.title,
          ),
          const Gap(BullSpacing.sm),
          Text(context.loc.limitOrdersCancelAllMessage),
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
    if (confirmed == true) bloc.add(const ListCancelAllPressed());
  }
}
