import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/currency_text.dart';
import 'package:bb_mobile/features/address_view/domain/address_overview.dart';
import 'package:bb_mobile/features/address_view/presentation/address_explorer_cubit.dart';
import 'package:bb_mobile/features/address_view/presentation/address_explorer_state.dart';
import 'package:bb_mobile/features/address_view/domain/address_view_failure.dart';
import 'package:bb_mobile/features/address_view/presentation/address_view_failure_l10n.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart'
    show LabelEntryBottomSheet;
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network;
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullPullableBody, BullSnackBar, BullText, BullTopBar, Gap;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AddressExplorerScreen extends StatelessWidget {
  const AddressExplorerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AddressExplorerScaffold(
      body: BlocBuilder<AddressExplorerCubit, AddressExplorerState>(
        builder: (context, state) {
          final cubit = context.read<AddressExplorerCubit>();
          final overview = state.overview;
          final failure = state.overviewFailure;

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
                    _AddressHeader(address: state.address),
                    const Gap(16),
                    _InfoRow(
                      label: context.loc.addressExplorerNetworkLabel,
                      value: BullText(
                        _networkName(context, state.network),
                        style: context.font.bodyMedium,
                        color: context.appColors.onSurface,
                      ),
                    ),
                    const Gap(16),
                    _OwnershipRow(ownership: state.ownership),
                    if (state.owner != null) ...[
                      const Gap(12),
                      _LabelsSection(
                        labels: state.labels,
                        failure: state.labelFailure,
                        onAdd: cubit.addLabel,
                      ),
                    ],
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
                    ] else if (overview != null)
                      ..._overviewSection(context, overview)
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

  List<Widget> _overviewSection(
    BuildContext context,
    AddressOverview overview,
  ) => [
    _InfoRow(
      label: context.loc.addressExplorerConfirmedBalance,
      value: CurrencyText(
        overview.confirmedSat,
        showFiat: false,
        style: context.font.bodyMedium,
        color: context.appColors.onSurface,
      ),
    ),
    const Gap(12),
    _InfoRow(
      label: context.loc.addressExplorerPendingBalance,
      value: CurrencyText(
        overview.unconfirmedSat,
        showFiat: false,
        style: context.font.bodyMedium,
        color: context.appColors.onSurface,
      ),
    ),
    const Gap(12),
    _InfoRow(
      label: context.loc.addressExplorerTransactionCount,
      value: BullText(
        overview.transactionCount.toString(),
        style: context.font.bodyMedium,
        color: context.appColors.onSurface,
      ),
    ),
    const Gap(24),
    if (overview.transactions.isEmpty)
      BullText(
        context.loc.addressExplorerNoTransactions,
        style: context.font.bodySmall,
        color: context.appColors.onSurfaceVariant,
        textAlign: .center,
      )
    else
      for (final transaction in overview.transactions)
        _TransactionTile(transaction: transaction),
  ];
}

class AddressExplorerUnavailableScreen extends StatelessWidget {
  const AddressExplorerUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AddressExplorerScaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: BullText(
            context.loc.addressExplorerMissingAddress,
            style: context.font.bodyMedium,
            color: context.appColors.onSurfaceVariant,
            textAlign: .center,
          ),
        ),
      ),
    );
  }
}

class _AddressExplorerScaffold extends StatelessWidget {
  final Widget body;

  const _AddressExplorerScaffold({required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: BullTopBar(
          title: context.loc.addressExplorerTitle,
          onBack: () => context.pop(),
        ),
      ),
      body: body,
    );
  }
}

class _AddressHeader extends StatelessWidget {
  final String address;

  const _AddressHeader({required this.address});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SelectableText(
            address,
            style: context.font.bodyLarge?.copyWith(
              color: context.appColors.onSurface,
            ),
          ),
        ),
        IconButton(
          tooltip: context.loc.walletDetailsCopyButton,
          icon: Icon(Icons.copy, size: 20, color: context.appColors.secondary),
          onPressed: () => _copy(
            context,
            text: address,
            message: context.loc.addressCardCopiedMessage,
          ),
        ),
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

class _OwnershipRow extends StatelessWidget {
  final AddressOwnership ownership;

  const _OwnershipRow({required this.ownership});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String text) = switch (ownership) {
      AddressOwnershipLoading() => (
        Icons.hourglass_empty,
        context.appColors.onSurfaceVariant,
        context.loc.addressExplorerOwnershipChecking,
      ),
      AddressOwnershipKnown(owner: final owner?) => (
        Icons.account_balance_wallet_outlined,
        context.appColors.success,
        context.loc.addressExplorerOwnedByWallet(owner.displayLabel(context)),
      ),
      AddressOwnershipKnown() => (
        Icons.info_outline,
        context.appColors.onSurfaceVariant,
        context.loc.addressExplorerNotOwned,
      ),
      AddressOwnershipUnavailable(:final failure) => (
        Icons.warning_amber_outlined,
        context.appColors.warning,
        failure.toTranslated(context),
      ),
    };

    return Row(
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
    );
  }
}

class _LabelsSection extends StatelessWidget {
  final List<String> labels;
  final AddressViewFailure? failure;
  final Future<void> Function(String label) onAdd;

  const _LabelsSection({
    required this.labels,
    required this.failure,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final failure = this.failure;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        _InfoRow(
          label: context.loc.addressExplorerLabels,
          value: BullText(
            labels.isEmpty
                ? context.loc.addressExplorerNoLabels
                : labels.join(', '),
            style: context.font.bodyMedium,
            color: context.appColors.onSurface,
            maxLines: 2,
          ),
        ),
        if (failure != null) ...[
          const Gap(4),
          BullText(
            failure.toTranslated(context),
            style: context.font.bodySmall,
            color: context.appColors.error,
          ),
        ],
        const Gap(8),
        BullButton.small(
          outlined: true,
          label: context.loc.addressExplorerAddLabel,
          onPressed: () async {
            final saved = await LabelEntryBottomSheet.label(
              context,
              title: context.loc.addressExplorerAddLabel,
            );
            if (saved == null) return;
            await onAdd(saved);
          },
          bgColor: context.appColors.surface,
          borderColor: context.appColors.text,
          textColor: context.appColors.text,
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final AddressTransaction transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _copy(
        context,
        text: transaction.txid,
        message: context.loc.addressExplorerTxidCopied,
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
                    _shortTxid(transaction.txid),
                    style: context.font.bodyMedium,
                    color: context.appColors.onSurface,
                  ),
                  const Gap(4),
                  BullText(
                    transaction.isConfirmed
                        ? context.loc.addressExplorerConfirmedAtBlock(
                            transaction.height,
                          )
                        : context.loc.addressExplorerUnconfirmed,
                    style: context.font.bodySmall,
                    color: transaction.isConfirmed
                        ? context.appColors.onSurfaceVariant
                        : context.appColors.warning,
                  ),
                ],
              ),
            ),
            Icon(Icons.copy, size: 16, color: context.appColors.textMuted),
          ],
        ),
      ),
    );
  }
}

Future<void> _copy(
  BuildContext context, {
  required String text,
  required String message,
}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  BullSnackBar.show(context, message: message);
}

String _shortTxid(String txid) => txid.length <= 20
    ? txid
    : '${txid.substring(0, 8)}…${txid.substring(txid.length - 8)}';

String _networkName(BuildContext context, Network network) => switch (network) {
  Network.bitcoinMainnet => context.loc.addressExplorerNetworkBitcoinMainnet,
  Network.bitcoinTestnet => context.loc.addressExplorerNetworkBitcoinTestnet,
  Network.bitcoinRegtest => context.loc.addressExplorerNetworkBitcoinRegtest,
  Network.liquidMainnet ||
  Network.liquidTestnet ||
  Network.liquidRegtest => context.loc.addressExplorerNetworkLiquid,
};
