import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_bottom_buttons.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_detail_balance_card.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_detail_txs_list.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class WalletDetailScreen extends StatelessWidget {
  const WalletDetailScreen({super.key, required this.walletId});

  final String walletId;

  @override
  Widget build(BuildContext context) {
    final wallet = context.select((WalletBloc bloc) {
      try {
        return bloc.state.wallets.firstWhere((w) => w.id == walletId);
      } catch (e) {
        return null;
      }
    });
    final walletName =
        wallet != null
            ? wallet.isDefault
                ? wallet.isLiquid
                    ? // TODO: use labels from translations for hardcoded names here
                    "Instant Payments"
                    : "Secure Bitcoin"
                : wallet.displayLabel
            : '';

    return Scaffold(
      appBar: AppBar(
        title:
            walletName.isEmpty
                ? const LoadingLineContent(width: 150)
                : BBText(walletName, style: context.font.headlineMedium),
        actions: [
          IconButton(
            onPressed: () {
              context.pushNamed(
                SettingsRoute.walletOptions.name,
                pathParameters: {'walletId': walletId},
              );
            },
            icon: const Icon(CupertinoIcons.settings),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (wallet == null)
            const LoadingBoxContent(height: 100)
          else
            BlocProvider<TransactionsCubit>(
              create:
                  (_) =>
                      locator<TransactionsCubit>(param1: walletId)..loadTxs(),
              child: Column(
                children: [
                  WalletDetailBalanceCard(
                    balanceSat: wallet.balanceSat.toInt(),
                    isLiquid: wallet.isLiquid,
                    signer: wallet.signer,
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
