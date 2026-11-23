import 'package:swap_feature/src/swap_l10n.dart';
import 'package:swap_feature/src/domain/entities/swap_wallet.dart';
import 'package:swap_feature/src/presentation/transfer_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullDropdown, BullPickerItem, BullShimmerLine, Gap, BullTypographyX;

class SwapToWalletDropdown extends StatelessWidget {
  const SwapToWalletDropdown();

  @override
  Widget build(BuildContext context) {
    final wallets = context.select((TransferBloc bloc) => bloc.state.wallets);
    final selected = context.select((TransferBloc bloc) => bloc.state.toWallet);
    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(
          context.swapCopyForLocale.swapToLabel,
          style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
        ),
        const Gap(4),
        if (wallets.isEmpty)
          const BullShimmerLine()
        else
          BullDropdown<SwapWallet>(
            items: [
              for (final wallet in wallets)
                BullPickerItem(
                  value: wallet,
                  label: wallet.swapWalletLabel(context),
                  leading: Image.asset(
                    wallet.isLiquid
                        ? 'assets/logos/liquid.png'
                        : 'assets/logos/bitcoin.png',
                    width: 20,
                    height: 20,
                  ),
                ),
            ],
            value: selected,
            validator: (value) {
              if (value == null) {
                return context.swapCopyForLocale.swapValidationSelectToWallet;
              }
              return null;
            },
            onChanged: (value) {
              final bloc = context.read<TransferBloc>();
              final currentFromWallet = bloc.state.fromWallet;
              if (currentFromWallet != null) {
                bloc.add(
                  TransferWalletsChanged(
                    fromWallet: currentFromWallet,
                    toWallet: value,
                  ),
                );
              }
            },
          ),
      ],
    );
  }
}
