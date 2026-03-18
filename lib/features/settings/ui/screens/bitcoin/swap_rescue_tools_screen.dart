import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/tables/details_table.dart';
import 'package:bb_mobile/core/widgets/tables/details_table_item.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/swap_rescue_cubit.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SwapRescueToolsScreen extends StatelessWidget {
  const SwapRescueToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SwapRescueCubit>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (cubit.state.swaps.isEmpty && !cubit.state.loading) {
        cubit.loadSwaps();
      }
    });

    return BlocConsumer<SwapRescueCubit, SwapRescueState>(
      listenWhen: (prev, curr) =>
          (prev.error != curr.error && curr.error != null) ||
          (prev.successMessage != curr.successMessage &&
              curr.successMessage != null),
      listener: (context, state) {
        if (state.error != null) {
          SnackBarUtils.showSnackBar(context, state.error!);
        }
        if (state.successMessage != null) {
          SnackBarUtils.showSnackBar(context, state.successMessage!);
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(context.loc.swapRescueToolsTitle),
          ),
          body: SafeArea(
            child: Stack(
              children: [
                _SwapList(swaps: state.swaps, loading: state.loading),
                if (state.actionLoading)
                  Container(
                    color: context.appColors.overlay,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: context.appColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SwapList extends StatelessWidget {
  const _SwapList({required this.swaps, required this.loading});

  final List<Swap> swaps;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (swaps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 48,
                color: context.appColors.textMuted,
              ),
              const Gap(16),
              BBText(
                context.loc.swapRescueToolsNoSwaps,
                style: context.font.bodyLarge?.copyWith(
                  color: context.appColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: swaps.length,
      separatorBuilder: (context, i) => Divider(
        height: 1,
        color: context.appColors.border,
      ),
      itemBuilder: (context, index) {
        return _SwapTile(swap: swaps[index]);
      },
    );
  }
}

class _SwapTile extends StatelessWidget {
  const _SwapTile({required this.swap});

  final Swap swap;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SwapRescueCubit>();

    return InkWell(
      onTap: () => _showSwapActions(context, cubit),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _SwapTypeIcon(swap: swap),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BBText(
                    _swapTypeLabel(context, swap),
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Gap(2),
                  BBText(
                    'ID: ${StringFormatting.truncateMiddle(swap.id)}',
                    style: context.font.bodySmall?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                  const Gap(2),
                  BBText(
                    _creationDateLabel(swap),
                    style: context.font.bodySmall?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(8),
            _StatusBadge(status: swap.status),
            const Gap(4),
            Icon(
              Icons.chevron_right,
              color: context.appColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _swapTypeLabel(BuildContext context, Swap swap) {
    return switch (swap.type) {
      SwapType.lightningToBitcoin => context.loc.swapRescueToolsTypeLnToBtc,
      SwapType.lightningToLiquid => context.loc.swapRescueToolsTypeLnToLbtc,
      SwapType.liquidToLightning => context.loc.swapRescueToolsTypeLbtcToLn,
      SwapType.bitcoinToLightning => context.loc.swapRescueToolsTypeBtcToLn,
      SwapType.liquidToBitcoin => context.loc.swapRescueToolsTypeLbtcToBtc,
      SwapType.bitcoinToLiquid => context.loc.swapRescueToolsTypeBtcToLbtc,
    };
  }

  String _creationDateLabel(Swap swap) {
    final dt = switch (swap) {
      LnReceiveSwap(:final creationTime) => creationTime,
      LnSendSwap(:final creationTime) => creationTime,
      ChainSwap(:final creationTime) => creationTime,
    };
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  void _showSwapActions(BuildContext context, SwapRescueCubit cubit) {
    BlurredBottomSheet.show(
      context: context,
      child: BlocProvider.value(
        value: cubit,
        child: _SwapActionsSheet(swap: swap),
      ),
    );
  }
}

class _SwapTypeIcon extends StatelessWidget {
  const _SwapTypeIcon({required this.swap});

  final Swap swap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (swap.type) {
      SwapType.lightningToBitcoin ||
      SwapType.lightningToLiquid => (Icons.arrow_downward, context.appColors.success),
      SwapType.bitcoinToLightning ||
      SwapType.liquidToLightning => (Icons.arrow_upward, context.appColors.warning),
      SwapType.liquidToBitcoin ||
      SwapType.bitcoinToLiquid => (Icons.swap_horiz, context.appColors.info),
    };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final SwapStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      SwapStatus.pending => (context.loc.coreSwapsStatusPending, context.appColors.warning),
      SwapStatus.paid => (context.loc.swapRescueToolsStatusPaid, context.appColors.info),
      SwapStatus.claimable => (context.loc.swapRescueToolsStatusClaimable, context.appColors.success),
      SwapStatus.refundable => (context.loc.swapRescueToolsStatusRefundable, context.appColors.error),
      SwapStatus.canCoop => (context.loc.swapRescueToolsStatusCanCoop, context.appColors.info),
      SwapStatus.completed => (context.loc.coreSwapsStatusCompleted, context.appColors.success),
      SwapStatus.expired => (context.loc.coreSwapsStatusExpired, context.appColors.textMuted),
      SwapStatus.failed => (context.loc.coreSwapsStatusFailed, context.appColors.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: BBText(
        label,
        style: context.font.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

enum _AddressType { claim, refund }

class _SwapActionsSheet extends StatelessWidget {
  const _SwapActionsSheet({required this.swap});

  final Swap swap;

  String? _currentClaimAddress() => switch (swap) {
    LnReceiveSwap(:final receiveAddress) => receiveAddress,
    ChainSwap(:final receiveAddress) => receiveAddress,
    LnSendSwap() => null,
  };

  String? _currentRefundAddress() => switch (swap) {
    LnSendSwap(:final refundAddress) => refundAddress,
    ChainSwap(:final refundAddress) => refundAddress,
    LnReceiveSwap() => null,
  };

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SwapRescueCubit>();
    final showClaim = swap is! LnSendSwap;
    final showRefund = swap is! LnReceiveSwap;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.appColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Gap(16),
          BBText(
            context.loc.swapRescueToolsSwapActionsTitle,
            style: context.font.titleMedium?.copyWith(
              color: context.appColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(8),
          DetailsTable(
            items: [
              DetailsTableItem(
                label: context.loc.swapRescueToolsIdLabel,
                displayValue: StringFormatting.truncateMiddle(swap.id),
                copyValue: swap.id,
              ),
              DetailsTableItem(
                label: context.loc.swapRescueToolsStatusLabel,
                displayValue: swap.status.name[0].toUpperCase() +
                    swap.status.name.substring(1),
              ),
              if (showClaim)
                DetailsTableItem(
                  label: context.loc.swapRescueToolsClaimAddressLabel,
                  displayValue: _currentClaimAddress() != null
                      ? StringFormatting.truncateMiddle(_currentClaimAddress()!)
                      : context.loc.swapRescueToolsAddressNotSet,
                  copyValue: _currentClaimAddress(),
                ),
              if (showRefund)
                DetailsTableItem(
                  label: context.loc.swapRescueToolsRefundAddressLabel,
                  displayValue: _currentRefundAddress() != null
                      ? StringFormatting.truncateMiddle(
                          _currentRefundAddress()!,
                        )
                      : context.loc.swapRescueToolsAddressNotSet,
                  copyValue: _currentRefundAddress(),
                ),
            ],
          ),
          const Gap(16),
          SettingsEntryItem(
            icon: Icons.check_circle_outline,
            iconColor: context.appColors.success,
            title: context.loc.swapRescueToolsMarkCompleted,
            onTap: () {
              Navigator.pop(context);
              _confirmMarkCompleted(context, cubit);
            },
          ),
          if (showClaim)
            SettingsEntryItem(
              icon: Icons.account_balance_wallet_outlined,
              iconColor: context.appColors.secondary,
              title: context.loc.swapRescueToolsUpdateClaimAddress,
              onTap: () {
                Navigator.pop(context);
                _showWalletSelection(context, cubit, _AddressType.claim);
              },
            ),
          if (showRefund)
            SettingsEntryItem(
              icon: Icons.undo,
              iconColor: context.appColors.warning,
              title: context.loc.swapRescueToolsUpdateRefundAddress,
              onTap: () {
                Navigator.pop(context);
                _showWalletSelection(context, cubit, _AddressType.refund);
              },
            ),
          const Gap(16),
          BBButton.big(
            label: context.loc.cancel,
            onPressed: () => Navigator.pop(context),
            bgColor: context.appColors.transparent,
            textColor: context.appColors.onSurface,
            outlined: true,
            borderColor: context.appColors.outline,
          ),
        ],
      ),
    );
  }

  void _confirmMarkCompleted(BuildContext context, SwapRescueCubit cubit) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.appColors.surface,
        title: Text(
          context.loc.swapRescueToolsMarkCompletedDialogTitle,
          style: context.font.headlineSmall?.copyWith(
            color: context.appColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          context.loc.swapRescueToolsMarkCompletedDialogContent,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.onSurface,
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              context.loc.cancel,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              cubit.markCompleted(swap.id);
            },
            child: Text(
              context.loc.confirmButton,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showWalletSelection(
    BuildContext context,
    SwapRescueCubit cubit,
    _AddressType addressType,
  ) {
    final allWallets = context.read<WalletBloc>().state.wallets;
    final wallets = addressType == _AddressType.claim
        ? cubit.walletsForClaim(swap, allWallets.toList())
        : cubit.walletsForRefund(swap, allWallets.toList());

    BlurredBottomSheet.show(
      context: context,
      child: BlocProvider.value(
        value: cubit,
        child: _WalletSelectionSheet(
          swap: swap,
          wallets: wallets,
          addressType: addressType,
        ),
      ),
    );
  }
}

class _WalletSelectionSheet extends StatelessWidget {
  const _WalletSelectionSheet({
    required this.swap,
    required this.wallets,
    required this.addressType,
  });

  final Swap swap;
  final List<Wallet> wallets;
  final _AddressType addressType;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SwapRescueCubit>();
    final isLiquid = addressType == _AddressType.claim
        ? cubit.claimIsLiquid(swap)
        : cubit.refundIsLiquid(swap);
    final networkLabel = isLiquid
        ? context.loc.swapRescueToolsNetworkLiquid
        : context.loc.swapRescueToolsNetworkBitcoin;
    final actionLabel = addressType == _AddressType.claim
        ? context.loc.swapRescueToolsAddressTypeClaim
        : context.loc.swapRescueToolsAddressTypeRefund;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.appColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Gap(16),
          BBText(
            context.loc.swapRescueToolsSelectWallet(networkLabel),
            style: context.font.titleMedium?.copyWith(
              color: context.appColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(4),
          BBText(
            context.loc.swapRescueToolsSelectWalletDescription(actionLabel),
            textAlign: TextAlign.center,
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
          const Gap(16),
          if (wallets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: BBText(
                context.loc.swapRescueToolsNoWalletsFound(networkLabel),
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.textMuted,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: wallets.length,
                separatorBuilder: (context, i) => Divider(
                  height: 1,
                  color: context.appColors.border,
                ),
                itemBuilder: (context, index) {
                  final wallet = wallets[index];
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    leading: Icon(
                      wallet.isLiquid
                          ? Icons.flash_on
                          : Icons.currency_bitcoin,
                      color: context.appColors.secondary,
                    ),
                    title: BBText(
                      wallet.displayLabel(context),
                      style: context.font.bodyMedium?.copyWith(
                        color: context.appColors.text,
                      ),
                    ),
                    subtitle: BBText(
                      wallet.networkString,
                      style: context.font.bodySmall?.copyWith(
                        color: context.appColors.textMuted,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: context.appColors.textMuted,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      if (addressType == _AddressType.claim) {
                        cubit.updateClaimAddress(swap.id, wallet.id);
                      } else {
                        cubit.updateRefundAddress(swap.id, wallet.id);
                      }
                    },
                  );
                },
              ),
            ),
          const Gap(8),
          BBButton.big(
            label: context.loc.cancel,
            onPressed: () => Navigator.pop(context),
            bgColor: context.appColors.transparent,
            textColor: context.appColors.onSurface,
            outlined: true,
            borderColor: context.appColors.outline,
          ),
        ],
      ),
    );
  }
}

