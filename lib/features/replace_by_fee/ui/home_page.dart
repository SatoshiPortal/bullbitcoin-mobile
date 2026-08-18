import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/widgets/inputs/bb_keyboard_actions.dart';
import 'package:bb_mobile/features/replace_by_fee/presentation/cubit.dart';
import 'package:bb_mobile/features/replace_by_fee/presentation/replace_by_fee_failure_l10n.dart';
import 'package:bb_mobile/features/replace_by_fee/presentation/state.dart';
import 'package:bb_mobile/features/replace_by_fee/ui/fee_selector_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class ReplaceByFeeHomePage extends StatefulWidget {
  final WalletTransaction tx;

  const ReplaceByFeeHomePage({super.key, required this.tx});

  @override
  State<ReplaceByFeeHomePage> createState() => _ReplaceByFeeHomePageState();
}

class _ReplaceByFeeHomePageState extends State<ReplaceByFeeHomePage> {
  final FocusNode _feeNode = FocusNode();

  @override
  void dispose() {
    _feeNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BullPage(
      topBar: BullTopBar(
        title: context.loc.replaceByFeeScreenTitle,
        onBack: context.pop,
      ),
      child: BBKeyboardActions(
        disableScroll: true,
        focusNodes: [_feeNode],
        child: BlocBuilder<ReplaceByFeeCubit, ReplaceByFeeState>(
          builder: (context, state) {
            final cubit = context.read<ReplaceByFeeCubit>();

            if (state.failure != null && state.newFeeRate == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: BullText(
                    state.failure!.toTranslated(context),
                    style: context.bullText.bodyMedium,
                    color: context.bull.error,
                  ),
                ),
              );
            }

            if (state.newFeeRate == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final originalFeeRate = widget.tx.feeSat / widget.tx.vsize;

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
                      txSize: widget.tx.vsize,
                      onChanged: cubit.onChangeFee,
                      onInvalid: cubit.markCustomFeeBelowFloor,
                      focusNode: _feeNode,
                      minRelay: state.minRelay,
                    ),
                    if (state.failure != null) ...[
                      const Gap(16),
                      BullText(
                        state.failure!.toTranslated(context),
                        style: context.bullText.bodyMedium,
                        color: context.bull.error,
                      ),
                      const Gap(16),
                    ],

                    BullButton.primary(
                      label: context.loc.replaceByFeeBroadcastButton,
                      onPressed: () => cubit.broadcast(),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOriginalTransaction(
    BuildContext context,
    double originalFeeRate,
  ) {
    return BullBorderedTile(
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          BullText(
            context.loc.replaceByFeeOriginalTransactionTitle,
            style: context.bullText.headlineLarge,
          ),
          const Gap(16),
          BullText(
            context.loc.replaceByFeeFeeRateDisplay(
              originalFeeRate.toStringAsFixed(1),
            ),
            style: context.bullText.labelMedium,
          ),
        ],
      ),
    );
  }
}
