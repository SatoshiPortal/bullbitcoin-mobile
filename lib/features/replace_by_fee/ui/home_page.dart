import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
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
        title: const Text('Replace by fee'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: BlocConsumer<ReplaceByFeeCubit, ReplaceByFeeState>(
        listener: (context, state) {
          // Handle side effects here if needed
        },
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
                      state.error!.message,
                      style: context.font.bodyMedium,
                      color: context.colour.error,
                    ),
                    const Gap(16),
                  ],

                  BBButton.big(
                    label: 'Broadcast',
                    onPressed: cubit.broadcast,
                    bgColor: context.theme.colorScheme.secondary,
                    textColor: context.theme.colorScheme.onSecondary,
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
      clipBehavior: Clip.hardEdge,
      color: context.colour.onSecondary,
      shadowColor: context.colour.secondary,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BBText('Original transaction', style: context.font.headlineLarge),
            const Gap(16),
            BBText(
              '${originalFeeRate.toStringAsFixed(1)} sat/vbyte',
              style: context.font.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
