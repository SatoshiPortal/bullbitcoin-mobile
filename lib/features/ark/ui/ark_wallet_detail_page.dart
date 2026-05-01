import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bb_refresh_indicator.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/ark/presentation/cubit.dart';
import 'package:bb_mobile/features/ark/router.dart';
import 'package:bb_mobile/features/ark/ui/ark_balance_detail_widget.dart';
import 'package:bb_mobile/features/ark/ui/settle_bottom_sheet.dart';
import 'package:bb_mobile/features/ark/ui/transaction_history_widget.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ArkWalletDetailPage extends StatelessWidget {
  const ArkWalletDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ArkCubit>();
    final state = context.watch<ArkCubit>().state;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.goNamed(WalletRoute.walletHome.name),
        ),
        title: Text(
          context.loc.arkInstantPayments,
          style: context.font.headlineMedium,
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.settings),
            onPressed: () => context.pushNamed(ArkRoute.arkAbout.name),
          ),
        ],
      ),
      body: SafeArea(
        child: BBRefreshIndicator(
          onRefresh: () async => await cubit.load(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: ArkBalanceDetailWidget(arkBalance: state.arkBalance),
              ),
              if (state.isLoading)
                SliverToBoxAdapter(
                  child: LinearProgressIndicator(
                    backgroundColor: context.appColors.surface,
                    color: context.appColors.primary,
                  ),
                ),
              const SliverToBoxAdapter(child: Gap(16.0)),
              SliverToBoxAdapter(
                child: TransactionHistoryWidget(
                  transactions: state.transactions,
                  isLoading: state.isLoading,
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  children: [
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(13.0),
                      child: BBButton.big(
                        label: context.loc.arkSettleTransactions,
                        onPressed: () => SettleBottomSheet.show(context, cubit),
                        bgColor: context.appColors.primary,
                        textColor: context.appColors.onPrimary,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(
                        left: 13.0,
                        right: 13.0,
                        bottom: 40.0,
                      ),
                      child: ArkWalletBottomButtons(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArkWalletBottomButtons extends StatelessWidget {
  const ArkWalletBottomButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BBButton.big(
            iconData: Icons.arrow_downward,
            label: context.loc.arkReceiveButton,
            iconFirst: true,
            onPressed: () {
              context.pushNamed(ArkRoute.arkReceive.name);
            },
            bgColor: context.appColors.onSurface,
            textColor: context.appColors.surface,
          ),
        ),
        const Gap(4),
        Expanded(
          child: BBButton.big(
            iconData: Icons.crop_free,
            label: context.loc.arkSendButton,
            iconFirst: true,
            onPressed: () {
              context.pushNamed(ArkRoute.arkSendRecipient.name);
            },
            bgColor: context.appColors.onSurface,
            textColor: context.appColors.surface,
            disabled: false,
          ),
        ),
      ],
    );
  }
}
