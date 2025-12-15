import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core_deprecated/widgets/buttons/button.dart';
import 'package:bb_mobile/core_deprecated/widgets/text/text.dart';
import 'package:bb_mobile/features/replace_by_fee/presentation/cubit.dart';
import 'package:bb_mobile/features/replace_by_fee/presentation/state.dart';
import 'package:bb_mobile/features/replace_by_fee/ui/fee_selector_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ReplaceByFeeHomePage extends StatelessWidget {
  final WalletTransaction tx;

  const ReplaceByFeeHomePage({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.replaceByFeeScreenTitle),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: BlocBuilder<ReplaceByFeeCubit, ReplaceByFeeState>(
        builder: (context, state) {
          final cubit = context.read<ReplaceByFeeCubit>();

          if (state.newFeeRate == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final originalFeeRate = tx.feeSat / tx.vsize;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildOriginalTransaction(context, originalFeeRate),
                  const Gap(16),
                  BumpFeeSelectorWidget(
                    fastestFeeRate: state.fastestFeeRate!,
                    selected: state.newFeeRate!,
                    txSize: tx.vsize,
                    onChanged: cubit.onChangeFee,
                  ),
                  if (state.error != null) ...[
                    const Gap(16),
                    BBText(
                      state.error!.toTranslated(context),
                      style: context.font.bodyMedium,
                      color: context.appColors.error,
                    ),
                    const Gap(16),
                  ],

                  BBButton.big(
                    label: context.loc.replaceByFeeBroadcastButton,
                    onPressed: () => cubit.broadcast(),
                    bgColor: context.appColors.secondary,
                    textColor: context.appColors.onSecondary,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOriginalTransaction(
    BuildContext context,
    double originalFeeRate,
  ) {
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(2),
      clipBehavior: .hardEdge,
      color: context.appColors.onSecondary,
      shadowColor: context.appColors.secondary,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            BBText(
              context.loc.replaceByFeeOriginalTransactionTitle,
              style: context.font.headlineLarge,
            ),
            const Gap(16),
            BBText(
              context.loc.replaceByFeeFeeRateDisplay(
                originalFeeRate.toStringAsFixed(1),
              ),
              style: context.font.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
