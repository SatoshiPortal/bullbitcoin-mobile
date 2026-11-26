import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:primitives/primitives.dart' show Sats;

import '../domain/ark_board_preparation.dart';
import '../domain/ark_display_data_port.dart';
import '../presentation/ark_board_cubit.dart';
import '../domain/ark_failure.dart';
import '../presentation/ark_failure_l10n.dart';
import '../presentation/ark_l10n.dart';
import '../presentation/ark_operation_status_l10n.dart';
import 'ark_amount.dart';
import 'ark_review.dart';
import 'ark_board_amount_screen.dart';
import 'ark_payment_progress_policy.dart';

class ArkBoardScreen extends StatefulWidget {
  final ArkBoardCubit cubit;
  final VoidCallback onReconcile;
  final ArkDisplayData? displayData;

  /// Opens this Board, by its funding transaction, in Ark's activity.
  final ValueChanged<String>? onViewDetails;

  /// Leaves the finished flow; without it, the screen just closes.
  final VoidCallback? onClose;

  /// The app's confirmation arrow, for the review header.
  final Widget? confirmIcon;

  /// Reads once whether payment transitions play; they do when absent.
  final Future<bool> Function()? readPaymentAnimations;

  const ArkBoardScreen({
    super.key,
    this.displayData,
    required this.cubit,
    required this.onReconcile,
    this.onViewDetails,
    this.onClose,
    this.confirmIcon,
    this.readPaymentAnimations,
  });
  @override
  State<ArkBoardScreen> createState() => _ArkBoardScreenState();
}

class _ArkBoardScreenState extends State<ArkBoardScreen> {
  late StreamSubscription<ArkBoardState> _subscription;

  /// The last state the user could act on. While the cubit is busy the
  /// screen they acted on stays, with progress, instead of a loading page.
  ArkBoardState? _settled;

  void _settle(ArkBoardState state) {
    if (state is! ArkBoardBusy && state is! ArkBoardPending) _settled = state;
    if (state case ArkBoardReviewed(:final preparation)) {
      _confirmed = preparation;
    }
  }

  /// The review last shown: what the success screen says reached Ark.
  ArkBoardPreparation? _confirmed;
  String? _transitionId;
  bool _showTransition = false;

  bool _left = false;

  /// A Board whose outcome the app cannot tell yet has no screen of its
  /// own: the flow closes, Ark is refreshed, and a snackbar says so. The
  /// app's own check then completes or releases that Board.
  void _leaveIfUnsettled(ArkBoardState state) {
    final unsettled = switch (state) {
      ArkBoardPending() => true,
      ArkBoardSubmitted(:final operation) => !_started(operation.status),
      _ => false,
    };
    if (!unsettled || _left) return;
    _left = true;
    final owner = widget.cubit;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only for the owner that left: never a replacement's handlers.
      if (!mounted || !identical(owner, widget.cubit)) return;
      final l10n = arkLocalizationsOf(context);
      BullSnackBar.show(
        context,
        message: switch (state) {
          ArkBoardSubmitted(:final operation)
              when operation.status != ArkOperationStatus.outcomeUnknown =>
            operation.status.toTranslated(context),
          _ => l10n.boardUncertain,
        },
      );
      widget.onReconcile();
      unawaited(Navigator.maybePop(context));
    });
  }

  static bool _started(ArkOperationStatus status) => switch (status) {
    ArkOperationStatus.prepared ||
    ArkOperationStatus.admitted ||
    ArkOperationStatus.pending ||
    ArkOperationStatus.succeeded => true,
    ArkOperationStatus.failed ||
    ArkOperationStatus.outcomeUnknown ||
    ArkOperationStatus.conflicted => false,
  };

  bool _current(ArkBoardCubit owner, ArkBoardState rendered) =>
      mounted &&
      identical(owner, widget.cubit) &&
      !owner.isClosed &&
      identical(rendered, owner.state);
  void _listen() {
    final owner = widget.cubit;
    _settled = null;
    // A new owner is a new Board: it may leave once of its own.
    _left = false;
    _settle(owner.state);
    _leaveIfUnsettled(owner.state);
    _subscription = owner.stream.listen((next) {
      if (mounted && identical(owner, widget.cubit)) {
        setState(() {
          _settle(next);
          if (next is ArkBoardReviewed) _showTransition = false;
        });
        _leaveIfUnsettled(next);
      }
    });
  }

  // Null until the preference is read: confirming waits for it, so a payment
  // can never take the animation path against a stored "off".
  bool? _animations;

  Future<void> _readAnimations() async {
    final read = widget.readPaymentAnimations;
    if (read == null) {
      _animations = true;
      return;
    }
    bool value;
    try {
      value = await read();
    } on Object {
      value = true;
    }
    if (mounted) setState(() => _animations = value);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_readAnimations());
    _listen();
  }

  @override
  void didUpdateWidget(ArkBoardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.cubit, widget.cubit)) {
      unawaited(_subscription.cancel());
      _showTransition = false;
      _transitionId = null;
      _listen();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  Widget _amount(
    ArkBoardCubit owner,
    ArkBoardEditing editing, {
    bool busy = false,
  }) => ArkBoardAmountScreen(
    // One form per editing state: a refusal starts a fresh form, while the
    // busy state that follows keeps the typed amount on screen.
    key: ValueKey(editing),
    config: owner.config,
    failure: editing.failure,
    displayData: widget.displayData,
    minimumBoard: owner.minimum,
    busy: busy,
    onReviewRequest: (config, amount) {
      if (_current(owner, editing) && identical(config, owner.config)) {
        unawaited(owner.prepare(amount));
      }
    },
  );

  Widget _review(
    ArkBoardCubit owner,
    ArkBoardReviewed reviewed, {
    bool busy = false,
  }) => _ArkBoardFrame(
    onBack: () => Navigator.pop(context),
    busy: busy,
    body: _ArkBoardReview(
      confirmIcon: widget.confirmIcon,
      preparation: reviewed.preparation,
      displayData: widget.displayData?.account == owner.config.id
          ? widget.displayData
          : null,
    ),
    action: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Like the app's confirm screens: why it was refused, in red, right
        // above the button. Nothing was signed, so the user may try again.
        if (reviewed.failure case final failure? when !busy)
          Padding(
            padding: const EdgeInsets.only(bottom: BullSpacing.xs),
            child: Semantics(
              liveRegion: true,
              child: BullText(
                failure.toTranslated(context),
                role: BullTextRole.body,
                fontWeight: FontWeight.w500,
                color: context.bull.error,
                textAlign: TextAlign.center,
                maxLines: 5,
              ),
            ),
          ),
        BullButton.primary(
          // An expired review is priced again by the same button.
          label: reviewed.failure is ArkReviewExpiredFailure && !busy
              ? arkLocalizationsOf(context).retry
              : arkLocalizationsOf(context).confirm,
          height: 56,
          onPressed: busy || _animations == null
              ? null
              : () {
                  if (_current(owner, reviewed)) {
                    final submission = owner.confirm();
                    if (owner.state is ArkBoardBusy &&
                        reviewed.failure is! ArkReviewExpiredFailure) {
                      setState(() {
                        _transitionId = reviewed.preparation.operationId;
                        _showTransition = _animations == true;
                      });
                    }
                    unawaited(submission);
                  }
                },
        ),
      ],
    ),
  );

  /// Like the app's other completed flows: a success check, what
  /// reaches Ark, and the way to this Board's details.
  Widget _success(ArkOperation operation) {
    final l10n = arkLocalizationsOf(context);
    final completed =
        operation.status == ArkOperationStatus.succeeded &&
        (_transitionId == null || operation.id == _transitionId);
    // For a Board the native reference is its funding transaction.
    final txid = operation.nativeReference;
    final net = _confirmed?.net;
    final fiat = net == null
        ? null
        : arkFiatText(context, net, widget.displayData?.price);
    final view = widget.onViewDetails;
    final colors = context.bull;
    return BullSuccessScreen(
      title: l10n.boardToArk,
      headline: completed ? l10n.boardCompleted : l10n.boardStarted,
      // Done: the success check. Started: under way, not yet a success.
      icon: completed
          ? null
          : ExcludeSemantics(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.surfaceContainerHighest,
                ),
                child: BullIcon(
                  BullIcons.schedule,
                  size: 32,
                  color: colors.textMuted,
                ),
              ),
            ),
      // Like Send's sent screen: the amount large, fiat under it, then
      // what happens next.
      message: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (net != null) ...[
            BullText(
              formatArkSats(context, net),
              role: BullTextRole.headline,
              fontWeight: FontWeight.w700,
              textAlign: TextAlign.center,
            ),
            if (fiat != null) ...[
              const Gap(BullSpacing.xxs),
              BullText(
                '~$fiat',
                role: BullTextRole.body,
                color: colors.textMuted,
                textAlign: TextAlign.center,
              ),
            ],
          ],
          if (!completed) ...[
            const Gap(BullSpacing.lg),
            Text(
              l10n.boardStartedMessage,
              style: context.bullType.label.copyWith(color: colors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      onClose: widget.onClose ?? () => Navigator.pop(context),
      actions: [
        if (view != null &&
            txid != null &&
            txid.trim().isNotEmpty &&
            (_transitionId == null || operation.id == _transitionId))
          BullButton.secondary(
            label: l10n.viewDetails,
            onPressed: () => view(txid),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final owner = widget.cubit;
    final state = owner.state;
    final transitionId = _transitionId;
    if (_showTransition && transitionId != null) {
      final operation = switch (state) {
        ArkBoardSubmitted(:final operation)
            when operation.id == transitionId &&
                operation.kind == ArkOperationKind.board =>
          operation,
        _ => null,
      };
      final phase = switch (operation?.status) {
        ArkOperationStatus.succeeded => BullPaymentPhase.success,
        ArkOperationStatus.failed ||
        ArkOperationStatus.conflicted => BullPaymentPhase.failed,
        _ => BullPaymentPhase.sending,
      };
      void dismiss() {
        if (mounted &&
            identical(owner, widget.cubit) &&
            _transitionId == transitionId) {
          setState(() => _showTransition = false);
        }
      }

      final l10n = arkLocalizationsOf(context);
      final progress = arkPaymentProgress(
        operation?.status,
        pendingState: BullPaymentStepState.broadcast,
        // Until an operation exists the funding is still being sent, and an
        // unknown outcome is not evidence of a broadcast.
        steps: [
          switch (operation?.status) {
            ArkOperationStatus.pending ||
            ArkOperationStatus.succeeded ||
            ArkOperationStatus.failed ||
            ArkOperationStatus.conflicted => l10n.operationFundingSent,
            ArkOperationStatus.outcomeUnknown => l10n.operationFundingUnknown,
            _ => l10n.operationSendingFunding,
          },
          l10n.operationCompleted,
        ],
      );
      return BullPaymentTransition(
        network: BullPaymentNetwork.ark,
        phase: phase,
        statusTag: operation?.status.toTranslated(context),
        progress: progress,
        status: operation?.status.toTranslated(context) ?? l10n.loading,
        skipLabel: BullUiLocalizations.of(context).paymentViewStatus,
        onSkip: dismiss,
        onBackdropTap: dismiss,
        onDone: dismiss,
      );
    }
    switch ((state, _settled)) {
      case (final ArkBoardEditing editing, _):
        return _amount(owner, editing);
      case (ArkBoardBusy(), final ArkBoardEditing editing):
        return _amount(owner, editing, busy: true);
      case (
        ArkBoardBusy() || ArkBoardPending(),
        final ArkBoardReviewed reviewed,
      ):
        return _review(owner, reviewed, busy: true);
      case (ArkBoardPending(), final ArkBoardEditing editing):
        return _amount(owner, editing, busy: true);
      case (ArkBoardBusy() || ArkBoardPending(), _):
        return _ArkBoardFrame(
          onBack: () => Navigator.pop(context),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [const BullLoader.large()],
            ),
          ),
        );
      case (final ArkBoardReviewed reviewed, _):
        return _review(owner, reviewed);
      case (ArkBoardSubmitted(:final operation), _):
        if (!_started(operation.status)) {
          // Leaving: the screen acted on stays until the flow closes.
          return switch (_settled) {
            final ArkBoardReviewed reviewed => _review(
              owner,
              reviewed,
              busy: true,
            ),
            _ => const SizedBox.shrink(),
          };
        }
        return _success(operation);
    }
  }
}

/// Top bar, scrollable body and pinned bottom action shared by Board steps.
class _ArkBoardFrame extends StatelessWidget {
  final VoidCallback onBack;
  final Widget body;
  final Widget? action;
  final bool busy;

  const _ArkBoardFrame({
    required this.onBack,
    required this.body,
    this.action,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final bottom = action;
    return BullScaffold(
      backgroundColor: context.bull.background,
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  BullSpacing.lg,
                  BullSpacing.sm,
                  BullSpacing.lg,
                  BullSpacing.lg,
                ),
                child: bottom,
              ),
            ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: BullSpacing.lg,
                bottom: BullSpacing.sm,
              ),
              child: BullTopBar(
                title: l10n.boardToArk,
                titleWidget: BullText(
                  l10n.boardToArk,
                  role: BullTextRole.subtitle,
                ),
                onBack: onBack,
              ),
            ),
            BullFadingLinearProgress(
              height: 3,
              trigger: busy,
              backgroundColor: context.bull.background,
              foregroundColor: context.bull.primary,
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// The durable funding review, as the app's send confirmation: its header,
/// then the facts between thin lines, each fee on its own row.
class _ArkBoardReview extends StatelessWidget {
  final ArkBoardPreparation preparation;
  final ArkDisplayData? displayData;
  final Widget? confirmIcon;

  const _ArkBoardReview({
    required this.preparation,
    this.displayData,
    this.confirmIcon,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final p = preparation;
    String sats(Sats amount) => formatArkSats(context, amount);
    final fiat = arkFiatText(context, p.fundingAmount, displayData?.price);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        BullSpacing.md,
        BullSpacing.lg,
        BullSpacing.md,
        BullSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArkReviewHeader(
            title: l10n.boardConfirmTitle,
            amount: sats(p.fundingAmount),
            icon: confirmIcon,
          ),
          const Gap(BullSpacing.xl),
          ArkReviewFacts(
            children: [
              ArkReviewFact(
                label: l10n.fromLabel,
                // The name is shown only for the wallet this review spends
                // from.
                value: switch (displayData) {
                  ArkDisplayData(
                    :final walletId,
                    walletName: ArkDefaultSourceWallet(),
                  )
                      when walletId == p.sourceWalletId =>
                    l10n.defaultBitcoinWalletLabel,
                  ArkDisplayData(
                    :final walletId,
                    walletName: ArkNamedSourceWallet(:final name),
                  )
                      when walletId == p.sourceWalletId &&
                          name.trim().isNotEmpty =>
                    name,
                  _ => l10n.boardSourceWallet,
                },
              ),
              ArkReviewFact(label: l10n.toLabel, value: l10n.title),
              ArkReviewFact(
                label: l10n.amountLabel,
                value: sats(p.fundingAmount),
                detail: fiat == null ? null : '~$fiat',
              ),
              ArkReviewFact(label: l10n.networkFees, value: sats(p.minerFee)),
              ArkReviewFact(label: l10n.boardArkFee, value: sats(p.arkFee)),
              ArkReviewFact(label: l10n.boardArkReceives, value: sats(p.net)),
            ],
          ),
        ],
      ),
    );
  }
}
