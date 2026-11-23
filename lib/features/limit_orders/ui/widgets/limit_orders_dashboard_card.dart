import 'package:primitives/primitives.dart' show FormatAmount;
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/limit_orders/presentation/limit_orders_cubit.dart';
import 'package:bb_mobile/features/limit_orders/presentation/limit_orders_failure_l10n.dart';
import 'package:bb_mobile/features/limit_orders/presentation/limit_orders_state.dart';
import 'package:bb_mobile/features/limit_orders/ui/limit_orders_router.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

final class LimitOrdersDashboardCard extends StatelessWidget {
  const LimitOrdersDashboardCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LimitOrdersCubit>().state;
    return BullBorderedTile(
      padding: const EdgeInsets.all(BullSpacing.md),
      backgroundColor: context.bull.surface,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _content(context, state),
      ),
    );
  }

  Widget _content(BuildContext context, LimitOrdersState state) {
    if (state.isLoading && state.orders.isEmpty) {
      return const Column(
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
      );
    }
    if (state.failure != null && state.orders.isEmpty) {
      return Column(
        key: const ValueKey('error'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            state.failure!.toTranslated(context),
            style: TextStyle(color: context.bull.error),
          ),
          const Gap(12),
          BullButton.secondary(
            size: BullButtonSize.small,
            label: context.loc.retry,
            onPressed: context.read<LimitOrdersCubit>().load,
          ),
        ],
      );
    }
    if (state.orders.isEmpty) {
      return InkWell(
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
      );
    }

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
        for (final order in state.orders) ...[
          InkWell(
            onTap: () async {
              final changed = await context.pushNamed<bool>(
                LimitOrdersRoute.details.name,
                pathParameters: {'orderId': order.id},
              );
              if (changed == true && context.mounted) {
                await context.read<LimitOrdersCubit>().load();
              }
            },
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
        if (!state.canCreate)
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
              onPressed: state.isCancellingAll
                  ? null
                  : () => _confirmCancelAll(context),
              size: BullButtonSize.small,
              compact: true,
            ),
            if (state.canCreate)
              BullButton.primary(
                label: context.loc.limitOrdersCreateNew,
                onPressed: () => _openCreate(context),
                size: BullButtonSize.small,
                compact: true,
              ),
          ],
        ),
        if (state.failure case final failure?)
          Text(
            failure.toTranslated(context),
            style: TextStyle(color: context.bull.error),
          ),
      ],
    );
  }

  Future<void> _openCreate(BuildContext context) async {
    final changed = await context.pushNamed<bool>(LimitOrdersRoute.create.name);
    if (changed == true && context.mounted) {
      await context.read<LimitOrdersCubit>().load();
    }
  }

  Future<void> _confirmCancelAll(BuildContext context) async {
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
    if (confirmed == true && context.mounted) {
      await context.read<LimitOrdersCubit>().cancelAll();
    }
  }
}
