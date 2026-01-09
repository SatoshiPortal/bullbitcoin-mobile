import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_coin_selection_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
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
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: .min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: BBText(
                  context.loc.sendAdvancedOptions,
                  style: context.font.headlineMedium,
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
              BBText(
                context.loc.sendReplaceByFeeActivated,
                style: context.font.headlineMedium,
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
            title: BBText(
              context.loc.sendSelectCoinsManually,
              style: context.font.bodyLarge?.copyWith(fontWeight: .w500),
            ),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              context.read<TransferBloc>().add(const TransferEvent.loadUtxos());
              BlurredBottomSheet.show(
                context: context,
                child: BlocProvider.value(
                  value: context.read<TransferBloc>(),
                  child: const SwapCoinSelectionBottomSheet(),
                ),
              );
            },
          ),
          const Gap(24),
          BBButton.big(
            label: context.loc.sendDone,
            onPressed: context.pop,
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
          ),
          const Gap(24),
        ],
      ),
    );
  }
}
