import 'package:bull_ui/app_theme.dart';
import 'package:send/src/send_localizations.dart';
import 'package:send/src/replace_by_fee/domain/replacement_target.dart';
import 'package:send/src/replace_by_fee/domain/replace_by_fee_failure.dart';
import 'package:send/src/replace_by_fee/presentation/cubit.dart';
import 'package:send/src/replace_by_fee/presentation/replace_by_fee_failure_l10n.dart';
import 'package:send/src/replace_by_fee/presentation/state.dart';
import 'package:send/src/replace_by_fee/ui/fee_selector_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullKeyboardActions,
        BullButton,
        BullFadingLinearProgress,
        BullShapesX,
        BullSupportButton,
        BullText,
        Gap,
        BullTypographyX;
import 'package:go_router/go_router.dart';

class ReplaceByFeeHomePage extends StatefulWidget {
  final ReplacementTarget tx;

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

  // Deliberate product choice: drafts sent to the support team stay in
  // English so support triages in one canonical language. The localized
  // swap draft (order_swap_under_review_card.dart) predates this decision.
  String _manipulatedTxSupportMessage() =>
      'Manipulated transaction warning (fee bump blocked).\n'
      'The app refused to accelerate a transaction because its signatures '
      'failed verification. This usually means the Electrum server replaced '
      'the original transaction (GHSA-6jp4-8v48-cc5v).\n'
      'Txid: ${widget.tx.txId}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.replaceByFeeScreenTitle),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: BlocSelector<ReplaceByFeeCubit, ReplaceByFeeState, bool>(
            selector: (state) =>
                state.newFeeRate == null && state.failure == null,
            builder: (context, loading) => BullFadingLinearProgress(
              trigger: loading,
              backgroundColor: context.appColors.surface,
              foregroundColor: context.appColors.primary,
            ),
          ),
        ),
      ),
      body: BullKeyboardActions(
        doneText: context.loc.doneButton,
        disableScroll: true,
        child: BlocBuilder<ReplaceByFeeCubit, ReplaceByFeeState>(
          builder: (context, state) {
            final cubit = context.read<ReplaceByFeeCubit>();

            final failure = state.failure;
            if (failure != null && state.newFeeRate == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BullText(
                        failure.toTranslated(context),
                        style: context.bullType.body,
                        color: context.appColors.error,
                      ),
                      if (failure
                          is ReplaceByFeeManipulatedTransactionFailure) ...[
                        const Gap(24),
                        BullSupportButton.big(
                          label: context.loc.replaceByFeeReportToSupport,
                          message: _manipulatedTxSupportMessage(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }

            if (state.newFeeRate == null) {
              return const SizedBox.shrink();
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
                        style: context.bullType.body,
                        color: context.appColors.error,
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
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(context.bullShapes.card),
      clipBehavior: .hardEdge,
      color: context.appColors.onSecondary,
      shadowColor: context.appColors.secondary,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            BullText(
              context.loc.replaceByFeeOriginalTransactionTitle,
              style: context.bullType.subtitle.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Gap(16),
            BullText(
              context.loc.replaceByFeeFeeRateDisplay(
                originalFeeRate.toStringAsFixed(1),
              ),
              style: context.bullType.caption,
            ),
          ],
        ),
      ),
    );
  }
}
