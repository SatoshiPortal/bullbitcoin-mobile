import 'package:bb_mobile/core/swaps/domain/entity/restored_swap.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/swap_rescue_cubit.dart';
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
              SnackBarUtils.showSnackBar(
                context,
                context.loc.swapRescueSuccess,
              );
              context.pop();
            } else if (state.status == SwapRescueStatus.error &&
                state.error != null) {
              SnackBarUtils.showSnackBar(context, state.error!);
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
                            displayValue:
                                swap.recoverable && !restorable.existsLocally
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
                          ),
                        ],
                      ),
                      const Gap(24),
                      _WalletSelector(state: state),
                      const Gap(24),
                      BullButton.big(
                        label: context.loc.swapRescueButton,
                        disabled: !swap.recoverable || !state.canRescue,
                        onPressed: swap.recoverable && state.canRescue
                            ? () => context.read<SwapRescueCubit>().rescue()
                            : () {},
                        bgColor: context.bull.primary,
                        textColor: context.bull.onPrimary,
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
          style: context.font.bodyMedium,
          color: context.bull.text,
        ),
        const Gap(8),
        BullDropdown<Wallet>(
          value: selected,
          hint: BullText(
            context.loc.swapRescueWalletHint,
            style: context.font.bodyMedium,
            color: context.bull.textMuted,
          ),
          items: state.wallets
              .map(
                (wallet) => DropdownMenuItem<Wallet>(
                  value: wallet,
                  child: BullText(
                    wallet.displayLabel(context),
                    style: context.font.bodyMedium,
                  ),
                ),
              )
              .toList(),
          onChanged: (wallet) {
            if (wallet != null) {
              context.read<SwapRescueCubit>().selectWallet(wallet.id);
            }
          },
        ),
      ],
    );
  }
}
