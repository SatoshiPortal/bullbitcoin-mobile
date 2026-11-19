import 'dart:async';

import 'package:ark/ark.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import 'package:bull_ui/bull_ui.dart';

import '../presentation/ark_board_cubit.dart';
import '../domain/ark_display_data_port.dart';
import '../domain/ark_board_minimum.dart';
import '../domain/ark_board_preparation.dart';
import 'ark_amount.dart';

import '../presentation/ark_l10n.dart';
import '../presentation/ark_failure_l10n.dart';
import '../presentation/ark_operation_status_l10n.dart';
import 'ark_board_amount_screen.dart';

final class _FundingDialog {
  final Object request;
  final BuildContext context;
  final ModalRoute<dynamic> route;
  final ArkBoardCubit owner;
  final ArkBoardState rendered;
  bool active = true;

  _FundingDialog(
    this.request,
    this.context,
    this.route,
    this.owner,
    this.rendered,
  );
}

class ArkBoardScreen extends StatefulWidget {
  final ArkBoardCubit cubit;
  final VoidCallback onReconcile;
  final ArkDisplayData? displayData;
  final ArkBoardMinimum? minimum;
  final ({String walletId, String label})? sourceLabel;
  final VoidCallback? onDone;
  final Uri? Function(ArkAccountId account, String txid)? fundingExplorer;
  final Future<void> Function(Uri uri)? onOpenExplorer;
  final Future<void> Function()? onSourceEntry;
  final VoidCallback? onRefreshSource;
  final bool Function()? sourceReady;
  const ArkBoardScreen({
    super.key,
    this.displayData,
    this.minimum,
    this.sourceLabel,
    this.onDone,
    this.fundingExplorer,
    this.onOpenExplorer,
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
  Object? _fundingRequest;
  _FundingDialog? _fundingDialog;

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
    _subscription = owner.stream.listen(
      (_) {
        if (mounted && identical(owner, widget.cubit)) {
          _retireFundingDialog();
          _enterSource();
          setState(() {});
        }
      },
      onDone: () {
        if (mounted && identical(owner, widget.cubit)) _retireFundingDialog();
      },
    );
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
      _retireFundingDialog();
      unawaited(_subscription.cancel());
      _detailsExpanded = false;
      _sourceEntered = false;
      _listen();
    }
    _enterSource();
  }

  @override
  void dispose() {
    _retireFundingDialog();
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
      ArkBoardSubmitted() => l10n.done,
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
            if (!_current(owner, rendered) ||
                ModalRoute.of(context)?.isCurrent != true) {
              return;
            }
            switch (rendered) {
              case ArkBoardReviewed():
                unawaited(owner.confirm());
              case ArkBoardPending():
                unawaited(owner.reconcile());
              case ArkBoardSubmitted():
                (widget.onDone ?? widget.onReconcile)();
              default:
                return;
            }
          },
          bgColor: rendered is ArkBoardReviewed
              ? context.bull.primary
              : context.bull.secondary,
          textColor: rendered is ArkBoardReviewed
              ? context.bull.onPrimary
              : context.bull.onSecondary,
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
        minimum: widget.minimum,
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
    final submitted = state is ArkBoardSubmitted ? state.operation : null;
    return BullScaffold(
      backgroundColor: context.bull.background,
      bottomNavigationBar: _footer(context, owner, state),
      body: SafeArea(
        child: Column(
          children: [
            BullTopBar(
              title: l10n.boardToArk,
              onBack: submitted == null ? () => Navigator.pop(context) : null,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (_, viewport) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    BullSpacing.lg,
                    BullSpacing.md,
                    BullSpacing.lg,
                    BullSpacing.lg,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          (viewport.maxHeight - BullSpacing.md - BullSpacing.lg)
                              .clamp(0.0, double.infinity)
                              .toDouble(),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: submitted == null
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        if (state is ArkBoardBusy) BullText(l10n.loading),
                        if (state case ArkBoardReviewed(:final preparation))
                          ..._review(context, preparation),
                        if (state case ArkBoardPending(
                          :final operationId,
                          :final failure,
                        )) ...[
                          BullText(
                            l10n.boardVerificationPending,
                            role: BullTextRole.title,
                          ),
                          const Gap(BullSpacing.md),
                          BullInfoBar(
                            message: failure.toTranslated(context),
                            tone: BullInfoTone.warning,
                          ),
                          BullInfoBar(message: l10n.uncertain),
                          if (operationId != null)
                            BullDetailsTable(
                              items: [
                                BullDetailsTableItem(
                                  label: l10n.id,
                                  displayValue: operationId,
                                ),
                              ],
                            ),
                        ],
                        if (submitted != null)
                          ..._submitted(context, owner, state, submitted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _review(BuildContext context, ArkBoardPreparation preparation) {
    final l10n = context.loc;
    final label = widget.sourceLabel;
    final sourceName =
        label != null &&
            label.walletId == preparation.sourceWalletId &&
            label.label.trim().isNotEmpty
        ? label.label
        : l10n.walletLabel;
    return [
      _hero(
        context,
        BullIcons.arrowUpward,
        l10n.boardConfirmation,
        formatArkObservedSats(context, preparation.fundingAmount),
      ),
      const Gap(BullSpacing.lg),
      _row(context, l10n.fromLabel, sourceName),
      _row(context, l10n.toLabel, l10n.title),
      _row(
        context,
        l10n.amountLabel,
        formatArkObservedSats(context, preparation.fundingAmount),
        secondary: ArkFiatAmount(
          amount: preparation.fundingAmount,
          price: widget.displayData?.account == preparation.account
              ? widget.displayData?.price
              : null,
        ),
      ),
      _row(
        context,
        l10n.networkFees,
        formatArkObservedSats(context, preparation.minerFee),
      ),
      _row(
        context,
        l10n.boardArkBoardingFee,
        formatArkObservedSats(context, preparation.arkFee),
      ),
      _row(
        context,
        l10n.totalLabel,
        formatArkObservedSats(context, preparation.sourceDebit),
      ),
      _row(
        context,
        l10n.boardArkBalanceReceives,
        formatArkObservedSats(context, preparation.net),
      ),
      const Gap(BullSpacing.md),
      Semantics(
        button: true,
        expanded: _detailsExpanded,
        child: BullBorderedTile(
          onTap: () => setState(() => _detailsExpanded = !_detailsExpanded),
          child: Row(
            children: [
              Expanded(
                child: BullText(l10n.boardDetails, role: BullTextRole.body),
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
              label: l10n.boardSourceWallet,
              displayValue: preparation.sourceWalletId,
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
              displayValue: preparation.validUntil.toUtc().toIso8601String(),
            ),
          ],
        ),
    ];
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    Widget? secondary,
  }) => Container(
    constraints: const BoxConstraints(minHeight: 52),
    padding: const EdgeInsets.symmetric(vertical: BullSpacing.sm),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: context.bull.outline)),
    ),
    child: Row(
      children: [
        Expanded(
          child: BullText(
            label,
            role: BullTextRole.body,
            color: context.bull.textMuted,
          ),
        ),
        const Gap(BullSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              BullText(
                value,
                role: BullTextRole.body,
                textAlign: TextAlign.end,
                fontWeight: FontWeight.w500,
              ),
              ?secondary,
            ],
          ),
        ),
      ],
    ),
  );

  Widget _hero(
    BuildContext context,
    IconData icon,
    String title,
    String? amount, {
    bool started = false,
  }) => Column(
    children: [
      Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.bull.outline.withValues(alpha: 0.4),
        ),
        child: BullIcon(
          icon,
          size: 32,
          color: started ? context.bull.success : context.bull.text,
        ),
      ),
      const Gap(BullSpacing.md),
      Semantics(
        header: true,
        child: BullText(
          title,
          textAlign: TextAlign.center,
          role: started ? BullTextRole.title : BullTextRole.body,
        ),
      ),
      if (amount != null) ...[
        const Gap(BullSpacing.sm),
        BullText(
          amount,
          role: BullTextRole.headline,
          textAlign: TextAlign.center,
        ),
      ],
    ],
  );

  String? _fundingTxid(ArkOperation operation) {
    final txid = operation.nativeReference;
    return operation.kind == ArkOperationKind.board &&
            txid != null &&
            RegExp(r'^[0-9a-f]{64}$').hasMatch(txid)
        ? txid
        : null;
  }

  List<Widget> _submitted(
    BuildContext context,
    ArkBoardCubit owner,
    ArkBoardState rendered,
    ArkOperation operation,
  ) {
    final l10n = context.loc;
    final txid = _fundingTxid(operation);
    final started =
        txid != null &&
        (operation.status == ArkOperationStatus.pending ||
            operation.status == ArkOperationStatus.succeeded);
    return [
      const Gap(BullSpacing.xl),
      if (started) ...[
        _hero(
          context,
          BullIcons.check,
          operation.status == ArkOperationStatus.succeeded
              ? l10n.operationCompleted
              : l10n.boardStarted,
          null,
          started: true,
        ),
        if (operation.status == ArkOperationStatus.pending) ...[
          const Gap(BullSpacing.md),
          BullText(
            l10n.boardStartedDescription,
            role: BullTextRole.body,
            textAlign: TextAlign.center,
            color: context.bull.textMuted,
          ),
        ],
      ] else ...[
        BullText(l10n.boardVerificationPending, role: BullTextRole.title),
        BullInfoBar(
          message: operation.status.toTranslated(context),
          tone: BullInfoTone.warning,
        ),
      ],
      const Gap(BullSpacing.xl),
      Semantics(
        button: txid != null,
        label: txid == null ? null : l10n.boardFundingOptions(txid),
        child: BullBorderedTile(
          backgroundColor: context.bull.surface,
          onTap: txid == null
              ? null
              : () {
                  if (_current(owner, rendered)) {
                    unawaited(_openFunding(context, owner, rendered, txid));
                  }
                },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: BullText(
                  l10n.boardFundingTransaction,
                  role: BullTextRole.label,
                ),
              ),
              const Gap(BullSpacing.sm),
              if (txid == null)
                BullText(l10n.boardFundingUnavailable, role: BullTextRole.body)
              else
                Row(
                  children: [
                    Expanded(
                      child: BullText(
                        '${txid.substring(0, 16)}…${txid.substring(txid.length - 12)}',
                        role: BullTextRole.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Gap(BullSpacing.sm),
                    Semantics(
                      button: true,
                      label: l10n.boardCopyFundingId,
                      child: BullButton.small(
                        label: '',
                        iconData: BullIcons.contentCopy,
                        width: 48,
                        height: 48,
                        bgColor: context.bull.secondary,
                        textColor: context.bull.onSecondary,
                        onPressed: () => unawaited(
                          _copyFunding(
                            owner,
                            rendered,
                            txid,
                            txid,
                            l10n.boardFundingIdCopied,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    ];
  }

  Uri? _explorer(ArkBoardCubit owner, String txid) {
    try {
      final uri = widget.fundingExplorer?.call(owner.config.id, txid);
      if (uri == null ||
          !uri.hasAuthority ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          (uri.scheme != 'https' && uri.scheme != 'http')) {
        return null;
      }
      return uri;
    } on Exception {
      return null;
    }
  }

  bool _dialogCurrent(_FundingDialog dialog) =>
      dialog.active &&
      identical(_fundingDialog, dialog) &&
      identical(_fundingRequest, dialog.request) &&
      _current(dialog.owner, dialog.rendered) &&
      dialog.context.mounted &&
      dialog.route.isActive &&
      dialog.route.isCurrent &&
      identical(ModalRoute.of(dialog.context), dialog.route);

  void _releaseFundingDialog(_FundingDialog dialog) {
    dialog.active = false;
    if (identical(_fundingDialog, dialog)) _fundingDialog = null;
    if (identical(_fundingRequest, dialog.request)) _fundingRequest = null;
  }

  void _retireFundingDialog() {
    final dialog = _fundingDialog;
    _fundingRequest = null;
    if (dialog == null) return;
    _releaseFundingDialog(dialog);
    _removeFundingRoute(dialog.route);
  }

  void _removeFundingRoute(ModalRoute<dynamic> route) {
    // The exact route may be covered; never pop the navigator's new top route.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = route.navigator;
      if (navigator != null && navigator.mounted && route.isActive) {
        navigator.removeRoute(route);
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> _copyFunding(
    ArkBoardCubit owner,
    ArkBoardState rendered,
    String txid,
    String value,
    String message, {
    Uri? expectedLink,
    _FundingDialog? dialog,
  }) async {
    if (!_current(owner, rendered) ||
        (dialog != null && !_dialogCurrent(dialog)) ||
        (dialog == null && ModalRoute.of(context)?.isCurrent != true) ||
        rendered is! ArkBoardSubmitted ||
        _fundingTxid(rendered.operation) != txid ||
        (expectedLink != null && _explorer(owner, txid) != expectedLink)) {
      return;
    }
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (_current(owner, rendered) &&
          (dialog == null || _dialogCurrent(dialog))) {
        BullSnackBar.show(context, message: message);
      }
    } on Exception {
      if (_current(owner, rendered) &&
          (dialog == null || _dialogCurrent(dialog))) {
        BullSnackBar.show(context, message: context.loc.nativeUnavailable);
      }
    }
  }

  Future<void> _openFunding(
    BuildContext context,
    ArkBoardCubit owner,
    ArkBoardState rendered,
    String txid,
  ) async {
    if (!_current(owner, rendered) ||
        _fundingRequest != null ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final request = Object();
    _fundingRequest = request;
    _FundingDialog? presented;
    try {
      await BullDialog.show<void>(
        context: context,
        builder: (dialogContext) {
          final route = ModalRoute.of(dialogContext);
          if (route == null) return const SizedBox.shrink();
          if (!identical(_fundingRequest, request) ||
              !_current(owner, rendered)) {
            _removeFundingRoute(route);
            return const SizedBox.shrink();
          }
          final dialog = _FundingDialog(
            request,
            dialogContext,
            route,
            owner,
            rendered,
          );
          presented = dialog;
          final previous = _fundingDialog;
          if (previous != null) previous.active = false;
          _fundingDialog = dialog;
          final l10n = dialogContext.loc;
          final link = _explorer(owner, txid);
          return PopScope<void>(
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) _releaseFundingDialog(dialog);
            },
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    namesRoute: true,
                    header: true,
                    child: BullText(
                      l10n.boardFundingId,
                      textAlign: TextAlign.center,
                      role: BullTextRole.subtitle,
                    ),
                  ),
                  const Gap(BullSpacing.md),
                  BullText(
                    txid,
                    textAlign: TextAlign.center,
                    role: BullTextRole.body,
                  ),
                  const Gap(BullSpacing.md),
                  BullButton.big(
                    label: l10n.boardCopyFundingId,
                    height: 48,
                    bgColor: dialogContext.bull.secondary,
                    textColor: dialogContext.bull.onSecondary,
                    onPressed: () => unawaited(
                      _copyFunding(
                        owner,
                        rendered,
                        txid,
                        txid,
                        l10n.boardFundingIdCopied,
                        dialog: dialog,
                      ),
                    ),
                  ),
                  if (link != null) ...[
                    const Gap(BullSpacing.sm),
                    BullButton.big(
                      label: l10n.boardCopyLink,
                      height: 48,
                      bgColor: dialogContext.bull.secondary,
                      textColor: dialogContext.bull.onSecondary,
                      onPressed: () => unawaited(
                        _copyFunding(
                          owner,
                          rendered,
                          txid,
                          link.toString(),
                          l10n.boardLinkCopied,
                          expectedLink: link,
                          dialog: dialog,
                        ),
                      ),
                    ),
                    if (widget.onOpenExplorer case final open?) ...[
                      const Gap(BullSpacing.sm),
                      BullButton.big(
                        label: l10n.boardViewInExplorer,
                        height: 48,
                        bgColor: dialogContext.bull.secondary,
                        textColor: dialogContext.bull.onSecondary,
                        onPressed: () async {
                          if (!_dialogCurrent(dialog) ||
                              _explorer(owner, txid) != link ||
                              !identical(open, widget.onOpenExplorer)) {
                            return;
                          }
                          try {
                            await open(link);
                          } on Exception {
                            if (_dialogCurrent(dialog)) {
                              BullSnackBar.show(
                                context,
                                message: context.loc.nativeUnavailable,
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ],
                  const Gap(BullSpacing.sm),
                  BullButton.big(
                    label: l10n.done,
                    height: 48,
                    bgColor: dialogContext.bull.secondary,
                    textColor: dialogContext.bull.onSecondary,
                    onPressed: () {
                      if (!_dialogCurrent(dialog)) return;
                      final navigator = dialog.route.navigator;
                      if (navigator == null || !navigator.mounted) return;
                      _releaseFundingDialog(dialog);
                      navigator.pop();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      final dialog = presented;
      if (dialog != null) _releaseFundingDialog(dialog);
      if (identical(_fundingRequest, request)) _fundingRequest = null;
    }
  }
}
