import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/dropdown/bb_dropdown.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SwapToWalletDropdown extends StatelessWidget {
  const SwapToWalletDropdown();

  @override
  Widget build(BuildContext context) {
    final wallets = context.select((TransferBloc bloc) => bloc.state.wallets);
    final selected = context.select((TransferBloc bloc) => bloc.state.toWallet);
    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(context.loc.swapToLabel, style: context.font.bodyLarge),
        const Gap(4),
        if (wallets.isEmpty)
          const LoadingLineContent()
        else
          BBDropdown<Wallet>(
            items: wallets
                .map(
                  (wallet) => DropdownMenuItem(
                    value: wallet,
                    child: Row(
                      children: [
                        Image.asset(
                          wallet.isLiquid
                              ? 'assets/logos/liquid.png'
                              : 'assets/logos/bitcoin.png',
                          width: 20,
                          height: 20,
                        ),
                        const Gap(8),
                        Text(wallet.displayLabel(context)),
                      ],
                    ),
                  ),
                )
                .toList(),
            value: selected,
            validator: (value) {
              if (value == null) {
                return context.loc.swapValidationSelectToWallet;
              }
              return null;
            },
            onChanged: (value) {
              if (value != null) {
                context.read<TransferBloc>().add(
                  TransferWalletsChanged(
                    fromWallet: context.read<TransferBloc>().state.fromWallet!,
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
