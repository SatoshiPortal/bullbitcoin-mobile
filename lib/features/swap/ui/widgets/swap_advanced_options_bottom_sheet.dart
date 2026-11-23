import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_coin_selection_bottom_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullBottomSheet,
        BullButton,
        BullShapesX,
        BullText,
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.bullShapes.sheet),
        ),
      ),
      child: Column(
        mainAxisSize: .min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: BullText(
                  context.loc.sendAdvancedOptions,
                  style: context.bullType.subtitle.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                child: IconButton(
                  iconSize: 24,
                  icon: const Icon(Icons.close),
                  onPressed: context.pop,
                ),
              ),
            ],
          ),
          const Gap(32),
          Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              BullText(
                context.loc.sendReplaceByFeeActivated,
                style: context.bullType.subtitle.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Switch(
                value: isRBFEnabled,
                onChanged: (val) {
                  context.read<TransferBloc>().add(
                    TransferEvent.replaceByFeeChanged(val),
                  );
                },
              ),
            ],
          ),
          const Gap(24),
          ListTile(
            title: BullText(
              context.loc.sendSelectCoinsManually,
              style: context.bullType.body
                  .copyWith(fontWeight: FontWeight.w500)
                  .copyWith(fontWeight: .w500),
            ),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              context.read<TransferBloc>().add(const TransferEvent.loadUtxos());
              BullBottomSheet.show(
                context: context,
                child: BlocProvider.value(
                  value: context.read<TransferBloc>(),
                  child: const SwapCoinSelectionBottomSheet(),
                ),
              );
            },
          ),
          const Gap(24),
          BullButton.secondary(
            label: context.loc.sendDone,
            onPressed: context.pop,
          ),
          const Gap(24),
        ],
      ),
    );
  }
}
