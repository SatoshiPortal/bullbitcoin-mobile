import 'package:swaps/swaps.dart';
import 'package:primitives/primitives.dart' show FormatAmount, LiquidNetwork;
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/swap_rescue_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/swaps_failure_l10n.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SwapRescueDetailsScreen extends StatelessWidget {
  const SwapRescueDetailsScreen({super.key, required this.restorable});

  final RestorableSwap restorable;

  @override
  Widget build(BuildContext context) {
    final swap = restorable.swap;
    return BullScaffold(
      body: SafeArea(
        child: BlocConsumer<SwapRescueCubit, SwapRescueState>(
          listenWhen: (a, b) => a.status != b.status,
          listener: (context, state) {
            if (state.status == SwapRescueStatus.success) {
              BullSnackBar.show(
                context,
                message: context.loc.swapRescueSuccess,
              );
              context.pop();
            } else if (state.status == SwapRescueStatus.error) {
              if (state.error case final error?) {
                BullSnackBar.show(
                  context,
                  message: error.toTranslated(context),
                );
              }
            }
          },
          builder: (context, state) {
            return Column(
              crossAxisAlignment: .stretch,
              children: [
                BullTopBar(
                  title: context.loc.swapRescueTitle,
                  onBack: () => context.pop(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      BullDetailsTable(
                        items: [
                          BullDetailsTableItem(
                            label: context.loc.swapRescueTypeLabel,
                            displayValue: _kindLabel(context, swap.kind),
                          ),
                          BullDetailsTableItem(
                            label: context.loc.swapRescueStatusLabel,
                            displayValue: restorable.isRescuable
                                ? context.loc.coreSwapsStatusPending
                                : context.loc.coreSwapsStatusCompleted,
                          ),
                          if (swap.amountSat > 0)
                            BullDetailsTableItem(
                              label: context.loc.swapRescueAmountLabel,
                              displayValue: FormatAmount.sats(swap.amountSat),
                            ),
                          BullDetailsTableItem(
                            label: context.loc.swapRescueRouteLabel,
                            displayValue: '${swap.fromAsset} → ${swap.toAsset}',
                          ),
                          BullDetailsTableItem(
                            label: context.loc.swapRescueCreatedLabel,
                            displayValue: _formatDate(swap.createdAt),
                          ),
                          BullDetailsTableItem(
                            label: context.loc.swapRescueIdLabel,
                            displayValue: swap.id,
                            copyValue: swap.id,
                            onCopied: () => BullSnackBar.show(
                              context,
                              message: context.loc.copiedToClipboard,
                            ),
                          ),
                        ],
                      ),
                      const Gap(24),
                      _WalletSelector(state: state),
                      const Gap(24),
                      BullButton.primary(
                        label: context.loc.swapRescueButton,
                        onPressed: (!swap.recoverable || !state.canRescue)
                            ? null
                            : () => context.read<SwapRescueCubit>().rescue(),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _kindLabel(BuildContext context, RestoredSwapKind kind) {
    switch (kind) {
      case RestoredSwapKind.lightningSend:
        return context.loc.swapRestoreKindLightningSend;
      case RestoredSwapKind.lightningReceive:
        return context.loc.swapRestoreKindLightningReceive;
      case RestoredSwapKind.crossChain:
        return context.loc.swapRestoreKindCrossChain;
    }
  }

  String _formatDate(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }
}

class _WalletSelector extends StatelessWidget {
  const _WalletSelector({required this.state});

  final SwapRescueState state;

  @override
  Widget build(BuildContext context) {
    final selected = state.wallets
        .where((w) => w.id == state.selectedWalletId)
        .firstOrNull;
    return Column(
      crossAxisAlignment: .start,
      children: [
        BullText(
          context.loc.swapRescueWalletLabel,
          style: context.bullType.body,
          color: context.bull.text,
        ),
        const Gap(8),
        BullDropdown<WalletRegistration>(
          value: selected,
          hint: context.loc.swapRescueWalletHint,
          items: [
            for (final wallet in state.wallets)
              BullPickerItem(
                value: wallet,
                label: _displayLabel(context, wallet),
              ),
          ],
          onChanged: (wallet) =>
              context.read<SwapRescueCubit>().selectWallet(wallet.id),
        ),
      ],
    );
  }

  String _displayLabel(BuildContext context, WalletRegistration wallet) {
    if (!wallet.isDefault) {
      return wallet.label ?? wallet.id.replaceFirst(RegExp(r':regtest$'), '');
    }
    return wallet.network is LiquidNetwork
        ? context.loc.globalDefaultLiquidWalletLabel
        : context.loc.globalDefaultBitcoinWalletLabel;
  }
}
