import 'package:swap_feature/src/swap_l10n.dart';
import 'package:swap_feature/src/presentation/transfer_bloc.dart';
import 'package:swap_feature/src/ui/widgets/swap_coin_selection_bottom_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullBottomSheet,
        BullIcon,
        BullIcons,
        BullInlineIconButton,
        BullSpacing,
        BullSwitch,
        BullThemeX,
        Gap,
        BullTypographyX;
import 'package:go_router/go_router.dart';

class SwapAdvancedOptionsBottomSheet extends StatelessWidget {
  const SwapAdvancedOptionsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final isRBFEnabled = context.select(
      (TransferBloc bloc) => bloc.state.replaceByFee,
    );

    void openCoins() {
      context.read<TransferBloc>().add(const TransferEvent.loadUtxos());
      BullBottomSheet.show(
        context: context,
        child: BlocProvider.value(
          value: context.read<TransferBloc>(),
          child: const SwapCoinSelectionBottomSheet(),
        ),
      );
    }

    void setRbf(bool value) => context.read<TransferBloc>().add(
      TransferEvent.replaceByFeeChanged(value),
    );

    // The layout of the send page's Advanced settings: a centred title with
    // close, then one row per option.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BullSpacing.md,
          BullSpacing.sm,
          BullSpacing.md,
          BullSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SizedBox(width: BullSpacing.xxl),
                Expanded(
                  child: Text(
                    context.swapCopyForLocale.sendAdvancedOptions,
                    textAlign: TextAlign.center,
                    style: context.bullType.subtitle,
                  ),
                ),
                BullInlineIconButton(
                  onPressed: context.pop,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const BullIcon(BullIcons.close),
                ),
              ],
            ),
            const Gap(BullSpacing.md),
            Semantics(
              label: context.swapCopyForLocale.sendReplaceByFeeActivated,
              toggled: isRBFEnabled,
              excludeSemantics: true,
              onTap: () => setRbf(!isRBFEnabled),
              child: GestureDetector(
                onTap: () => setRbf(!isRBFEnabled),
                child: Container(
                  color: context.bull.transparent,
                  constraints: const BoxConstraints(minHeight: BullSpacing.xxl),
                  padding: const EdgeInsets.symmetric(vertical: BullSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.swapCopyForLocale.sendReplaceByFeeActivated,
                          style: context.bullType.body,
                        ),
                      ),
                      BullSwitch(value: isRBFEnabled, onChanged: setRbf),
                    ],
                  ),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: context.swapCopyForLocale.sendSelectCoinsManually,
              excludeSemantics: true,
              onTap: openCoins,
              child: GestureDetector(
                onTap: openCoins,
                child: Container(
                  color: context.bull.transparent,
                  constraints: const BoxConstraints(minHeight: BullSpacing.xxl),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.swapCopyForLocale.sendSelectCoinsManually,
                          style: context.bullType.body,
                        ),
                      ),
                      const BullIcon(BullIcons.chevronRight),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
