import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/spark/presentation/cubit.dart';
import 'package:bb_mobile/features/spark/router.dart';
import 'package:bb_mobile/features/spark/ui/spark_balance_detail_widget.dart';
import 'package:bb_mobile/features/spark/ui/spark_transaction_history_widget.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SparkWalletDetailPage extends StatelessWidget {
  const SparkWalletDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SparkCubit>();
    final state = context.watch<SparkCubit>().state;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.goNamed(WalletRoute.walletHome.name),
        ),
        title: Text(
          'Spark Instant Payments',
          style: context.font.headlineMedium,
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.settings),
            onPressed: () => context.pushNamed(SparkRoute.sparkAbout.name),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: RefreshIndicator(
                onRefresh: () async => await cubit.load(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 120.0),
                  child: Column(
                    children: [
                      SparkBalanceDetailWidget(
                        sparkBalance: state.sparkBalance,
                      ),
                      if (state.isLoading)
                        LinearProgressIndicator(
                          backgroundColor: context.colour.surface,
                          color: context.colour.primary,
                        ),
                      const Gap(16.0),
                      SparkTransactionHistoryWidget(
                        payments: state.payments,
                        isLoading: state.isLoading,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.only(left: 13.0, right: 13.0, bottom: 40.0),
                child: SparkWalletBottomButtons(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SparkWalletBottomButtons extends StatelessWidget {
  const SparkWalletBottomButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BBButton.big(
            iconData: Icons.arrow_downward,
            label: 'Receive',
            iconFirst: true,
            onPressed: () {
              context.pushNamed(SparkRoute.sparkReceive.name);
            },
            bgColor: context.colour.secondary,
            textColor: context.colour.onPrimary,
          ),
        ),
        const Gap(4),
        Expanded(
          child: BBButton.big(
            iconData: Icons.crop_free,
            label: 'Send',
            iconFirst: true,
            onPressed: () {
              context.pushNamed(SparkRoute.sparkSend.name);
            },
            bgColor: context.colour.secondary,
            textColor: context.colour.onPrimary,
          ),
        ),
      ],
    );
  }
}
