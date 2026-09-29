import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/features/limit_orders/presentation/limit_orders_cubit.dart';
import 'package:bb_mobile/features/limit_orders/presentation/limit_orders_failure_l10n.dart';
import 'package:bb_mobile/features/limit_orders/presentation/limit_orders_state.dart';
import 'package:bb_mobile/features/limit_orders/ui/limit_orders_router.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
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
          LoadingLineContent(
            height: 16,
            padding: EdgeInsets.symmetric(vertical: 6),
          ),
          LoadingLineContent(
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
          BullButton.small(
            label: context.loc.retry,
            onPressed: context.read<LimitOrdersCubit>().load,
            bgColor: context.bull.secondary,
            textColor: context.bull.onSecondary,
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
                style: Theme.of(context).textTheme.titleMedium,
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
                style: Theme.of(context).textTheme.titleMedium,
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
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const Gap(8),
        Row(
          children: [
            TextButton(
              onPressed: state.isCancellingAll
                  ? null
                  : () => _confirmCancelAll(context),
              style: _actionButtonStyle(context),
              child: Text(context.loc.limitOrdersCancelAll),
            ),
            const Spacer(),
            if (state.canCreate)
              TextButton(
                onPressed: () => _openCreate(context),
                style: _actionButtonStyle(context),
                child: Text(context.loc.limitOrdersCreateNew),
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

  ButtonStyle _actionButtonStyle(BuildContext context) => TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: Theme.of(context).textTheme.titleMedium,
  );

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
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Gap(BullSpacing.sm),
          Text(context.loc.limitOrdersCancelAllMessage),
          const Gap(BullSpacing.lg),
          BullButton.big(
            label: context.loc.limitOrdersDialogConfirm,
            onPressed: () => Navigator.pop(dialogContext, true),
            bgColor: context.bull.primary,
            textColor: context.bull.onPrimary,
          ),
          const Gap(BullSpacing.sm),
          BullButton.big(
            label: context.loc.cancel,
            onPressed: () => Navigator.pop(dialogContext, false),
            bgColor: context.bull.surface,
            textColor: context.bull.text,
            outlined: true,
            borderColor: context.bull.border,
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<LimitOrdersCubit>().cancelAll();
    }
  }
}
