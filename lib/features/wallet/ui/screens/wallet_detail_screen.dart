import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:bb_mobile/features/wallet/presentation/blocs/detail/wallet_detail_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_bottom_buttons.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_detail_balance_card.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_detail_txs_list.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/ui/components/loading/loading_box_content.dart';
import 'package:bb_mobile/ui/components/loading/loading_line_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class WalletDetailScreen extends StatelessWidget {
  const WalletDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = context.select((WalletDetailBloc bloc) => bloc.state.wallet);
    final walletName =
        wallet != null
            ? wallet.isDefault
                ? wallet.isLiquid
                    ? // TODO: use labels from translations for hardcoded names here
                    "Instant Payments"
                    : "Secure Bitcoin"
                : wallet.getLabel() ?? ''
            : '';

    return Scaffold(
      appBar: AppBar(
        title:
            walletName.isEmpty
                ? const LoadingLineContent(width: 150)
                : Text(walletName),
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (wallet == null)
            const LoadingBoxContent(size: 100)
          else
            BlocProvider<TransactionsCubit>(
              create:
                  (_) =>
                      locator<TransactionsCubit>(param1: wallet.id)..loadTxs(),
              child: Column(
                children: [
                  WalletDetailBalanceCard(
                    balanceSat: wallet.balanceSat.toInt(),
                    isLiquid: wallet.isLiquid,
                    walletSource: wallet.source,
                  ),
                  const Gap(16.0),
                  const WalletDetailTxsList(),
                  const Gap(96),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 40),
            child: WalletBottomButtons(wallet: wallet),
          ),
        ],
      ),
    );
  }
}
