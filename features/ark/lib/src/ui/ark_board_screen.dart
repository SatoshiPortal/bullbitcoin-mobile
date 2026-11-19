import 'dart:async';

import 'package:bull_ui/bull_ui.dart';

import '../presentation/ark_board_cubit.dart';
import '../domain/ark_display_data_port.dart';
import 'ark_amount.dart';

import '../presentation/ark_l10n.dart';
import '../presentation/ark_failure_l10n.dart';
import '../presentation/ark_operation_status_l10n.dart';
import 'ark_board_amount_screen.dart';

class ArkBoardScreen extends StatefulWidget {
  final ArkBoardCubit cubit;
  final VoidCallback onReconcile;
  final ArkDisplayData? displayData;
  final Future<void> Function()? onSourceEntry;
  final VoidCallback? onRefreshSource;
  final bool Function()? sourceReady;
  const ArkBoardScreen({
    super.key,
    this.displayData,
    this.onSourceEntry,
    this.onRefreshSource,
    this.sourceReady,
    required this.cubit,
    required this.onReconcile,
  });
  @override
  State<ArkBoardScreen> createState() => _ArkBoardScreenState();
}

class _ArkBoardScreenState extends State<ArkBoardScreen> {
  late StreamSubscription<ArkBoardState> _subscription;
  bool _detailsExpanded = false;
  bool _sourceEntered = false;

  void _enterSource() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _sourceEntered ||
          widget.cubit.state is! ArkBoardEditing) {
        return;
      }
      final enter = widget.onSourceEntry;
      if (enter == null) return;
      _sourceEntered = true;
      unawaited(enter());
    });
  }

  bool _current(ArkBoardCubit owner, ArkBoardState rendered) =>
      mounted &&
      identical(owner, widget.cubit) &&
      !owner.isClosed &&
      identical(rendered, owner.state);
  void _listen() {
    final owner = widget.cubit;
    _subscription = owner.stream.listen((_) {
      if (mounted && identical(owner, widget.cubit)) {
        _enterSource();
        setState(() {});
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _listen();
    _enterSource();
  }

  @override
  void didUpdateWidget(ArkBoardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.cubit, widget.cubit)) {
      unawaited(_subscription.cancel());
      _detailsExpanded = false;
      _sourceEntered = false;
      _listen();
    }
    _enterSource();
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  Widget? _footer(
    BuildContext context,
    ArkBoardCubit owner,
    ArkBoardState rendered,
  ) {
    final l10n = arkLocalizationsOf(context);
    final label = switch (rendered) {
      ArkBoardReviewed() => l10n.confirm,
      ArkBoardPending(:final operationId) when operationId != null =>
        l10n.refresh,
      ArkBoardSubmitted() => l10n.refresh,
      _ => null,
    };
    if (label == null) return null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BullSpacing.lg,
          BullSpacing.sm,
          BullSpacing.lg,
          BullSpacing.lg,
        ),
        child: BullButton.big(
          label: label,
          onPressed: () {
            if (!_current(owner, rendered)) return;
            switch (rendered) {
              case ArkBoardReviewed():
                unawaited(owner.confirm());
              case ArkBoardPending():
                unawaited(owner.reconcile());
              case ArkBoardSubmitted():
                widget.onReconcile();
              default:
                return;
            }
          },
          bgColor: context.bull.text,
          textColor: context.bull.surface,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final owner = widget.cubit;
    final state = owner.state;
    final l10n = arkLocalizationsOf(context);
    if (state is ArkBoardEditing) {
      return ArkBoardAmountScreen(
        key: ValueKey(state),
        config: owner.config,
        failure: state.failure,
        displayData: widget.displayData,
        sourceReady: widget.sourceReady == null
            ? null
            : () =>
                  _current(owner, state) &&
                  (widget.sourceReady?.call() ?? false),
        onRefreshSource: widget.onRefreshSource == null
            ? null
            : () {
                if (_current(owner, state)) widget.onRefreshSource?.call();
              },
        onReviewRequest: (config, amount) {
          if (_current(owner, state) &&
              identical(config, owner.config) &&
              (widget.sourceReady?.call() ?? true)) {
            unawaited(
              owner.prepare(
                amount,
                expectedSourceWalletId: widget.sourceReady == null
                    ? null
                    : widget.displayData?.walletId,
              ),
            );
          }
        },
      );
    }
    return BullScaffold(
      backgroundColor: context.bull.background,
      bottomNavigationBar: _footer(context, owner, state),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BullSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BullTopBar(
                title: l10n.boardToArk,
                onBack: () => Navigator.pop(context),
              ),
              if (state is! ArkBoardReviewed)
                BullInfoBar(message: l10n.boardFastPolicy),
              if (state is ArkBoardBusy) BullText(l10n.loading, style: null),
              if (state case ArkBoardReviewed(:final preparation)) ...[
                const Gap(BullSpacing.lg),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.bull.surfaceContainer,
                    ),
                    child: BullIcon(
                      BullIcons.arrowUpward,
                      size: 32,
                      color: context.bull.text,
                    ),
                  ),
                ),
                const Gap(BullSpacing.lg),
                BullText(
                  l10n.boardConfirmation,
                  textAlign: TextAlign.center,
                  role: BullTextRole.body,
                ),
                const Gap(BullSpacing.sm),
                Center(
                  child: BullText(
                    formatArkSats(context, preparation.fundingAmount),
                    role: BullTextRole.headline,
                  ),
                ),
                ArkFiatAmount(
                  amount: preparation.fundingAmount,
                  price: widget.displayData?.account == owner.config.id
                      ? widget.displayData?.price
                      : null,
                ),
                const Gap(BullSpacing.xl),
                BullDetailsTable(
                  items: [
                    BullDetailsTableItem(
                      label: l10n.boardSourceWallet,
                      displayValue: preparation.sourceWalletId,
                    ),
                    BullDetailsTableItem(
                      label: l10n.toLabel,
                      displayValue: l10n.title,
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
                  ],
                ),
                const Gap(BullSpacing.md),
                Semantics(
                  button: true,
                  expanded: _detailsExpanded,
                  child: BullBorderedTile(
                    onTap: () =>
                        setState(() => _detailsExpanded = !_detailsExpanded),
                    child: Row(
                      children: [
                        Expanded(
                          child: BullText(
                            l10n.boardDetails,
                            role: BullTextRole.body,
                          ),
                        ),
                        BullIcon(
                          _detailsExpanded
                              ? BullIcons.removeCircleOutline
                              : BullIcons.addCircleOutline,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_detailsExpanded)
                  BullDetailsTable(
                    items: [
                      BullDetailsTableItem(
                        label: l10n.exitProgressFeeRate,
                        displayValue: preparation.feeRate.satsPerVbyte
                            .toString(),
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
              ],
            ],
          ),
        ),
      ),
    );
  }
}
