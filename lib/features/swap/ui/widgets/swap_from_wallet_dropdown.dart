import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SwapFromWalletDropdown extends StatelessWidget {
  const SwapFromWalletDropdown();

  @override
  Widget build(BuildContext context) {
    final wallets = context.select((TransferBloc bloc) => bloc.state.wallets);
    final selected = context.select(
      (TransferBloc bloc) => bloc.state.fromWallet,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Transfer From', style: context.font.bodyLarge),
        const Gap(4),
        if (wallets.isEmpty)
          const LoadingLineContent()
        else
          SizedBox(
            height: 56,
            child: Material(
              elevation: 4,
              color: context.colour.onPrimary,
              borderRadius: BorderRadius.circular(4.0),
              child: Center(
                child: DropdownButtonFormField<Wallet>(
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                  ),
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: context.colour.secondary,
                  ),
                  items:
                      wallets
                          .map(
                            (wallet) => DropdownMenuItem(
                              value: wallet,
                              child: Text(wallet.displayLabel),
                            ),
                          )
                          .toList(),
                  value: selected,
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a wallet to transfer from';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    if (value != null) {
                      context.read<TransferBloc>().add(
                        TransferWalletsChanged(
                          fromWallet: value,
                          toWallet:
                              context.read<TransferBloc>().state.toWallet!,
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
