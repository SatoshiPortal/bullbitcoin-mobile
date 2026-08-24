import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/tiles/bordered_tappable_tile.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/send/public/send_facade.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_pending_transactions_cubit.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class WalletPendingTransactionsSection extends StatelessWidget {
  const WalletPendingTransactionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final transactions = context.select(
      (WalletPendingTransactionsCubit cubit) => cubit.state.transactions,
    );
    final invalidCount = context.select(
      (WalletPendingTransactionsCubit cubit) => cubit.state.invalidCount,
    );
    final failure = context.select(
      (WalletPendingTransactionsCubit cubit) => cubit.state.failure,
    );
    if (transactions.isEmpty && invalidCount == 0 && failure == null) {
      return const SliverToBoxAdapter();
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BBText(
              context.loc.sendPendingTransactionsTitle,
              style: context.font.bodyLarge?.copyWith(fontWeight: .w500),
              color: context.appColors.secondary,
            ),
            const Gap(8),
            if (failure != null) ...[
              InfoCard(
                description: context.loc.oopsSomethingWentWrong,
                tagColor: context.appColors.error,
                bgColor: context.appColors.errorContainer,
              ),
              const Gap(8),
              BBButton.small(
                label: context.loc.retry,
                onPressed: context.read<WalletPendingTransactionsCubit>().retry,
                bgColor: context.appColors.secondary,
                textColor: context.appColors.onSecondary,
              ),
              if (transactions.isNotEmpty || invalidCount > 0) const Gap(8),
            ],
            if (invalidCount > 0) ...[
              InfoCard(
                description: context.loc.sendPendingTransactionsInvalid,
                tagColor: context.appColors.error,
                bgColor: context.appColors.errorContainer,
              ),
              if (transactions.isNotEmpty) const Gap(8),
            ],
            for (final (index, transaction) in transactions.indexed) ...[
              _PendingTransactionTile(transaction: transaction),
              if (index != transactions.length - 1) const Gap(8),
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingTransactionTile extends StatelessWidget {
  final PendingBitcoinTransaction transaction;

  const _PendingTransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final label = transaction.label?.trim();
    final parsedAmount = int.tryParse(transaction.amount);
    final amount = switch ((parsedAmount, transaction.amountCurrencyCode)) {
      (final sats?, 'sats') when sats > 0 => FormatAmount.sats(sats),
      _ when transaction.amount.trim().isNotEmpty =>
        '${transaction.amount} ${transaction.amountCurrencyCode}',
      _ => null,
    };
    final fallback = transaction.isDraft
        ? amount == null
              ? context.loc.sendDraftFallback
              : context.loc.sendDraftFallbackAmount(amount)
        : amount == null
        ? context.loc.sendTransactionFallback
        : context.loc.sendTransactionFallbackAmount(amount);
    return BorderedTappableTile(
      onTap: () => context.pushNamed(
        SendRoute.send.name,
        extra: SendRouteArgs(pendingTransactionId: transaction.id),
      ),
      child: Row(
        children: [
          Icon(
            transaction.isDraft ? Icons.edit_outlined : Icons.key_outlined,
            color: context.appColors.secondary,
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText(
                  label == null || label.isEmpty ? fallback : label,
                  style: context.font.bodyMedium,
                  color: context.appColors.secondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(2),
                BBText(
                  _status(context),
                  style: context.font.bodySmall,
                  color: transaction.isConflict
                      ? context.appColors.error
                      : context.appColors.textMuted,
                ),
              ],
            ),
          ),
          PopupMenuButton<_PendingAction>(
            onSelected: (_) => _delete(context),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _PendingAction.delete,
                child: Text(
                  transaction.isDraft
                      ? context.loc.sendDeleteDraft
                      : context.loc.sendSigningDeleteLocalCopy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _status(BuildContext context) {
    if (transaction.isConflict) return context.loc.sendPendingConflict;
    return switch (transaction.stage) {
      PendingBitcoinTransactionStage.draft => context.loc.sendPendingDraft,
      PendingBitcoinTransactionStage.needsSignatures =>
        context.loc.sendSignersNeeded(transaction.signersNeeded),
      PendingBitcoinTransactionStage.readyToBroadcast =>
        context.loc.sendSigningReady,
    };
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          transaction.isDraft
              ? context.loc.sendDeleteDraft
              : context.loc.sendSigningDeleteLocalCopy,
        ),
        content: transaction.isDraft
            ? null
            : Text(context.loc.sendSigningDeleteWarning),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(false),
            child: Text(context.loc.cancel),
          ),
          TextButton(
            onPressed: () => dialogContext.pop(true),
            child: Text(context.loc.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final deleted = await context
          .read<WalletPendingTransactionsCubit>()
          .delete(transaction);
      if (!deleted && context.mounted) {
        SnackBarUtils.showSnackBar(context, context.loc.oopsSomethingWentWrong);
      }
    }
  }
}

enum _PendingAction { delete }
