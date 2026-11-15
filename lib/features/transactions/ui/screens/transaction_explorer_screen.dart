import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/currency_text.dart';
import 'package:bb_mobile/features/address_view/public/address_explorer_route.dart';
import 'package:bb_mobile/features/transactions/domain/entities/explored_transaction.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_explorer/transaction_explorer_cubit.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_explorer/transaction_explorer_state.dart';
import 'package:bb_mobile/features/transactions/presentation/transaction_failure_l10n.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' show Wallet;
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullPullableBody, BullSnackBar, BullText, BullTopBar, Gap;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class TransactionExplorerScreen extends StatelessWidget {
  const TransactionExplorerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _TransactionExplorerScaffold(
      body: BlocBuilder<TransactionExplorerCubit, TransactionExplorerState>(
        builder: (context, state) {
          final cubit = context.read<TransactionExplorerCubit>();
          final transaction = state.transaction;
          final failure = state.failure;

          return BullPullableBody(
            onRefresh: cubit.load,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _TxidHeader(txid: state.txid),
                    const Gap(16),
                    _OwnershipSection(
                      txid: state.txid,
                      ownership: state.ownership,
                    ),
                    const Gap(24),
                    if (failure != null) ...[
                      BullText(
                        failure.toTranslated(context),
                        style: context.font.bodyMedium,
                        color: context.appColors.error,
                        textAlign: .center,
                        maxLines: 3,
                      ),
                      const Gap(16),
                      BullButton.big(
                        label: context.loc.retry,
                        onPressed: cubit.load,
                        bgColor: context.appColors.secondary,
                        textColor: context.appColors.onSecondary,
                      ),
                    ] else if (transaction != null)
                      ..._transactionSection(context, transaction)
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _transactionSection(
    BuildContext context,
    ExploredTransaction transaction,
  ) => [
    _InfoRow(
      label: context.loc.transactionExplorerTotalOutput,
      value: CurrencyText(
        transaction.totalOutputSat,
        showFiat: false,
        style: context.font.bodyMedium,
        color: context.appColors.onSurface,
      ),
    ),
    const Gap(12),
    _InfoRow(
      label: context.loc.transactionExplorerInputs,
      value: _value(context, transaction.inputCount.toString()),
    ),
    const Gap(12),
    _InfoRow(
      label: context.loc.transactionExplorerSize,
      value: _value(
        context,
        context.loc.transactionExplorerBytes(transaction.sizeBytes),
      ),
    ),
    const Gap(12),
    _InfoRow(
      label: context.loc.transactionExplorerVirtualSize,
      value: _value(
        context,
        context.loc.transactionExplorerVirtualBytes(
          transaction.virtualSizeBytes,
        ),
      ),
    ),
    const Gap(12),
    _InfoRow(
      label: context.loc.transactionExplorerVersion,
      value: _value(context, transaction.version.toString()),
    ),
    const Gap(12),
    _InfoRow(
      label: context.loc.transactionExplorerLocktime,
      value: _value(context, transaction.locktime.toString()),
    ),
    const Gap(24),
    BullText(
      context.loc.transactionExplorerOutputs(transaction.outputs.length),
      style: context.font.titleMedium,
      color: context.appColors.onSurface,
    ),
    const Gap(8),
    for (final output in transaction.outputs)
      _OutputTile(output: output, transaction: transaction),
  ];

  Widget _value(BuildContext context, String text) => BullText(
    text,
    style: context.font.bodyMedium,
    color: context.appColors.onSurface,
  );
}

class TransactionExplorerUnavailableScreen extends StatelessWidget {
  const TransactionExplorerUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _TransactionExplorerScaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: BullText(
            context.loc.transactionExplorerMissingTxid,
            style: context.font.bodyMedium,
            color: context.appColors.onSurfaceVariant,
            textAlign: .center,
          ),
        ),
      ),
    );
  }
}

class _TransactionExplorerScaffold extends StatelessWidget {
  final Widget body;

  const _TransactionExplorerScaffold({required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: BullTopBar(
          title: context.loc.transactionExplorerTitle,
          onBack: () => context.pop(),
        ),
      ),
      body: body,
    );
  }
}

class _TxidHeader extends StatelessWidget {
  final String txid;

  const _TxidHeader({required this.txid});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SelectableText(
            txid,
            style: context.font.bodyLarge?.copyWith(
              color: context.appColors.onSurface,
            ),
          ),
        ),
        IconButton(
          tooltip: context.loc.walletDetailsCopyButton,
          icon: Icon(Icons.copy, size: 20, color: context.appColors.secondary),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: txid));
            if (!context.mounted) return;
            BullSnackBar.show(
              context,
              message: context.loc.addressExplorerTxidCopied,
            );
          },
        ),
      ],
    );
  }
}

class _OwnershipSection extends StatelessWidget {
  final String txid;
  final TransactionOwnership ownership;

  const _OwnershipSection({required this.txid, required this.ownership});

  @override
  Widget build(BuildContext context) {
    final Wallet? owner = switch (ownership) {
      TransactionOwnershipKnown(:final owner) => owner,
      TransactionOwnershipLoading() ||
      TransactionOwnershipUnavailable() => null,
    };
    final (IconData icon, Color color, String text) = switch (ownership) {
      TransactionOwnershipLoading() => (
        Icons.hourglass_empty,
        context.appColors.onSurfaceVariant,
        context.loc.addressExplorerOwnershipChecking,
      ),
      TransactionOwnershipKnown(owner: final wallet?) => (
        Icons.account_balance_wallet_outlined,
        context.appColors.success,
        context.loc.transactionExplorerOwnedByWallet(
          wallet.displayLabel(context),
        ),
      ),
      TransactionOwnershipKnown() => (
        Icons.info_outline,
        context.appColors.onSurfaceVariant,
        context.loc.transactionExplorerNotOwned,
      ),
      TransactionOwnershipUnavailable() => (
        Icons.warning_amber_outlined,
        context.appColors.warning,
        context.loc.transactionExplorerOwnershipUnknown,
      ),
    };

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: color),
            const Gap(12),
            Expanded(
              child: BullText(
                text,
                style: context.font.bodyMedium,
                color: context.appColors.onSurface,
                maxLines: 2,
              ),
            ),
          ],
        ),
        if (owner != null) ...[
          const Gap(12),
          BullButton.small(
            outlined: true,
            label: context.loc.transactionExplorerOpenDetails,
            onPressed: () => context.pushNamed(
              TransactionsRoute.transactionDetails.name,
              pathParameters: {'txId': txid.trim().toLowerCase()},
              queryParameters: {'walletId': owner.id},
            ),
            bgColor: context.appColors.surface,
            borderColor: context.appColors.text,
            textColor: context.appColors.text,
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final Widget value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BullText(
          label,
          style: context.font.bodyMedium,
          color: context.appColors.onSurfaceVariant,
        ),
        const Gap(12),
        Expanded(
          child: Align(alignment: .centerRight, child: value),
        ),
      ],
    );
  }
}

class _OutputTile extends StatelessWidget {
  final ExploredTransactionOutput output;
  final ExploredTransaction transaction;

  const _OutputTile({required this.output, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final address = output.address;
    return InkWell(
      onTap: address == null
          ? null
          : () => context.pushNamed(
              AddressExplorerRoute.addressExplorer.name,
              extra: AddressExplorerArgs(
                address: address,
                network: transaction.network,
              ),
            ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  BullText(
                    address ?? context.loc.transactionExplorerNoAddress,
                    style: context.font.bodyMedium,
                    color: address == null
                        ? context.appColors.onSurfaceVariant
                        : context.appColors.onSurface,
                    maxLines: 2,
                  ),
                  const Gap(4),
                  CurrencyText(
                    output.amountSat,
                    showFiat: false,
                    style: context.font.bodySmall,
                    color: context.appColors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            if (address != null)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: context.appColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}
