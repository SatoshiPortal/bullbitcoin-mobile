import 'package:swaps/swaps.dart';
import 'package:primitives/primitives.dart' show FormatAmount, LiquidNetwork;
import '../../../generated/l10n/swap_localizations.dart';
import 'package:secrets/secrets.dart';
import '../presentation/swap_rescue_cubit.dart';
import '../presentation/swaps_failure_l10n.dart';
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
                message: SwapLocalizations.of(context).swapRescueSuccess,
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
                  title: SwapLocalizations.of(context).swapRescueTitle,
                  onBack: () => context.pop(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      BullDetailsTable(
                        items: [
                          BullDetailsTableItem(
                            label: SwapLocalizations.of(context).swapRescueTypeLabel,
                            displayValue: _kindLabel(context, swap.kind),
                          ),
                          BullDetailsTableItem(
                            label: SwapLocalizations.of(context).swapRescueStatusLabel,
                            displayValue: restorable.isRescuable
                                ? SwapLocalizations.of(context).coreSwapsStatusPending
                                : SwapLocalizations.of(context).coreSwapsStatusCompleted,
                          ),
                          if (swap.amountSat > 0)
                            BullDetailsTableItem(
                              label: SwapLocalizations.of(context).swapRescueAmountLabel,
                              displayValue: FormatAmount.sats(swap.amountSat),
                            ),
                          BullDetailsTableItem(
                            label: SwapLocalizations.of(context).swapRescueRouteLabel,
                            displayValue: '${swap.fromAsset} → ${swap.toAsset}',
                          ),
                          BullDetailsTableItem(
                            label: SwapLocalizations.of(context).swapRescueCreatedLabel,
                            displayValue: _formatDate(swap.createdAt),
                          ),
                          BullDetailsTableItem(
                            label: SwapLocalizations.of(context).swapRescueIdLabel,
                            displayValue: swap.id,
                            copyValue: swap.id,
                            onCopied: () => BullSnackBar.show(
                              context,
                              message: SwapLocalizations.of(context).copiedToClipboard,
                            ),
                          ),
                        ],
                      ),
                      const Gap(24),
                      _WalletSelector(state: state),
                      const Gap(24),
                      BullButton.primary(
                        label: SwapLocalizations.of(context).swapRescueButton,
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
        return SwapLocalizations.of(context).swapRestoreKindLightningSend;
      case RestoredSwapKind.lightningReceive:
        return SwapLocalizations.of(context).swapRestoreKindLightningReceive;
      case RestoredSwapKind.crossChain:
        return SwapLocalizations.of(context).swapRestoreKindCrossChain;
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
          SwapLocalizations.of(context).swapRescueWalletLabel,
          style: context.bullType.body,
          color: context.bull.text,
        ),
        const Gap(8),
        BullDropdown<WalletRegistration>(
          value: selected,
          hint: SwapLocalizations.of(context).swapRescueWalletHint,
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
        ? SwapLocalizations.of(context).globalDefaultLiquidWalletLabel
        : SwapLocalizations.of(context).globalDefaultBitcoinWalletLabel;
  }
}
