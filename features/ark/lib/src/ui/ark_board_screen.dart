import 'dart:async';

import 'package:bull_ui/bull_ui.dart';

import '../presentation/ark_board_cubit.dart';
import '../presentation/ark_l10n.dart';
import '../presentation/ark_failure_l10n.dart';
import '../presentation/ark_operation_status_l10n.dart';
import 'ark_board_amount_screen.dart';

class ArkBoardScreen extends StatefulWidget {
  final ArkBoardCubit cubit;
  final VoidCallback onReconcile;
  const ArkBoardScreen({
    super.key,
    required this.cubit,
    required this.onReconcile,
  });
  @override
  State<ArkBoardScreen> createState() => _ArkBoardScreenState();
}

class _ArkBoardScreenState extends State<ArkBoardScreen> {
  late StreamSubscription<ArkBoardState> _subscription;
  bool _current(ArkBoardCubit owner, ArkBoardState rendered) =>
      mounted &&
      identical(owner, widget.cubit) &&
      !owner.isClosed &&
      identical(rendered, owner.state);
  void _listen() {
    final owner = widget.cubit;
    _subscription = owner.stream.listen((_) {
      if (mounted && identical(owner, widget.cubit)) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(ArkBoardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.cubit, widget.cubit)) {
      unawaited(_subscription.cancel());
      _listen();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owner = widget.cubit;
    final state = owner.state;
    final l10n = arkLocalizationsOf(context);
    if (state is ArkBoardEditing) {
      return ArkBoardAmountScreen(
        config: owner.config,
        onReviewRequest: (config, amount) {
          if (_current(owner, state) && identical(config, owner.config)) {
            unawaited(owner.prepare(amount));
          }
        },
      );
    }
    return BullScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BullSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BullTopBar(
                title: l10n.board,
                onBack: () => Navigator.pop(context),
              ),
              BullInfoBar(message: l10n.boardFastPolicy),
              if (state is ArkBoardBusy) BullText(l10n.loading, style: null),
              if (state case ArkBoardReviewed(:final preparation)) ...[
                BullDetailsTable(
                  items: [
                    BullDetailsTableItem(
                      label: l10n.boardSourceWallet,
                      displayValue: preparation.sourceWalletId,
                    ),
                    BullDetailsTableItem(
                      label: l10n.amount,
                      displayValue: preparation.fundingAmount.value.toString(),
                    ),
                    BullDetailsTableItem(
                      label: l10n.boardMinerFeeInSats,
                      displayValue: preparation.minerFee.value.toString(),
                    ),
                    BullDetailsTableItem(
                      label: l10n.boardArkFeeInSats,
                      displayValue: preparation.arkFee.value.toString(),
                    ),
                    BullDetailsTableItem(
                      label: l10n.boardSourceDebitInSats,
                      displayValue: preparation.sourceDebit.value.toString(),
                    ),
                    BullDetailsTableItem(
                      label: l10n.netInSats,
                      displayValue: preparation.net.value.toString(),
                    ),
                    BullDetailsTableItem(
                      label: l10n.exitProgressFeeRate,
                      displayValue: preparation.feeRate.satsPerVbyte.toString(),
                    ),
                    BullDetailsTableItem(
                      label: l10n.transactionId,
                      displayValue: preparation.unsignedTxid,
                    ),
                    BullDetailsTableItem(
                      label: l10n.expiryHeight,
                      displayValue: preparation.expiryHeight.toString(),
                    ),
                    BullDetailsTableItem(
                      label: l10n.boardValidUntil,
                      displayValue: preparation.validUntil
                          .toUtc()
                          .toIso8601String(),
                    ),
                  ],
                ),
                BullButton.big(
                  label: l10n.confirm,
                  onPressed: () {
                    if (_current(owner, state)) unawaited(owner.confirm());
                  },
                  bgColor: context.bull.primary,
                  textColor: context.bull.onPrimary,
                ),
              ],
              if (state case ArkBoardPending(
                :final operationId,
                :final failure,
              )) ...[
                BullInfoBar(
                  message: failure.toTranslated(context),
                  tone: BullInfoTone.warning,
                ),
                BullInfoBar(message: l10n.uncertain),
                if (operationId != null) ...[
                  BullDetailsTable(
                    items: [
                      BullDetailsTableItem(
                        label: l10n.id,
                        displayValue: operationId,
                      ),
                    ],
                  ),
                  BullButton.big(
                    label: l10n.refresh,
                    onPressed: () {
                      if (_current(owner, state)) unawaited(owner.reconcile());
                    },
                    bgColor: context.bull.primary,
                    textColor: context.bull.onPrimary,
                  ),
                ],
              ],
              if (state case ArkBoardSubmitted(:final operation)) ...[
                BullDetailsTable(
                  items: [
                    BullDetailsTableItem(
                      label: l10n.id,
                      displayValue: operation.id,
                    ),
                    BullDetailsTableItem(
                      label: l10n.state,
                      displayValue: operation.status.toTranslated(context),
                    ),
                  ],
                ),
                BullButton.big(
                  label: l10n.refresh,
                  onPressed: () {
                    if (_current(owner, state)) widget.onReconcile();
                  },
                  bgColor: context.bull.primary,
                  textColor: context.bull.onPrimary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
