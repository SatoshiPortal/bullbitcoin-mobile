import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';

import '../presentation/ark_claim_recovery_cubit.dart';
import '../presentation/ark_failure_l10n.dart';
import '../presentation/ark_l10n.dart';

class ArkClaimRecoveryScreen extends StatefulWidget {
  final ArkClaimRecoveryCubit cubit;
  const ArkClaimRecoveryScreen({super.key, required this.cubit});
  @override
  State<ArkClaimRecoveryScreen> createState() => _ArkClaimRecoveryScreenState();
}

class _ArkClaimRecoveryScreenState extends State<ArkClaimRecoveryScreen> {
  late StreamSubscription<ArkClaimRecoveryState> _subscription;
  @override
  void initState() {
    super.initState();
    _listen();
    widget.cubit.load();
  }

  void _listen() {
    _subscription = widget.cubit.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(ArkClaimRecoveryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cubit != widget.cubit) {
      _subscription.cancel();
      _listen();
      widget.cubit.load();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final state = widget.cubit.state;
    final selection = switch (state) {
      ArkClaimRecoveryReady(:final selection) ||
      ArkClaimRecoverySubmitting(:final selection) => selection,
      ArkClaimRecoveryFailed(:final lastReview) => lastReview,
      _ => null,
    };
    return BullScaffold(
      backgroundColor: context.bull.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            BullSpacing.md,
            BullSpacing.zero,
            BullSpacing.md,
            BullSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BullTopBar(
                title: l10n.signedClaimRecovery,
                titleWidget: BullText(
                  l10n.signedClaimRecovery,
                  role: BullTextRole.title,
                ),
                onBack: () => Navigator.pop(context),
              ),
              const Gap(BullSpacing.md),
              if (selection != null) ...[
                BullDetailsTable(
                  items: [
                    BullDetailsTableItem(
                      label: l10n.claimTxid,
                      displayValue: selection.summary.txid,
                      copyValue: selection.summary.txid,
                      copiedMessage: l10n.copied,
                    ),
                    BullDetailsTableItem(
                      label: l10n.claimDestination,
                      displayValue: selection.summary.destination,
                    ),
                    BullDetailsTableItem(
                      label: l10n.netInSats,
                      displayValue: selection.summary.net.toString(),
                    ),
                    BullDetailsTableItem(
                      label: l10n.feeInSats,
                      displayValue: selection.summary.fee.toString(),
                    ),
                    BullDetailsTableItem(
                      label: l10n.actualVtxos,
                      displayValue: selection.operation.actualIds.length
                          .toString(),
                    ),
                    BullDetailsTableItem(
                      label: l10n.skippedVtxos,
                      displayValue: selection.operation.skippedIds.length
                          .toString(),
                    ),
                  ],
                ),
                const Gap(BullSpacing.md),
              ],
              if (state is ArkClaimRecoveryLoading ||
                  state is ArkClaimRecoverySubmitting) ...[
                const Center(child: BullLoader.large()),
                const Gap(BullSpacing.sm),
              ],
              if (state is ArkClaimRecoveryReady ||
                  state is ArkClaimRecoverySubmitting)
                BullButton.big(
                  label: l10n.reannounceSignedClaim,
                  disabled: state is ArkClaimRecoverySubmitting,
                  onPressed: widget.cubit.confirm,
                  bgColor: context.bull.primary,
                  textColor: context.bull.onPrimary,
                ),
              if (state case ArkClaimRecoveryFailed(:final failure)) ...[
                // Refused: why, in red, as the app shows it.
                BullText(
                  failure.toTranslated(context),
                  role: BullTextRole.body,
                  fontWeight: FontWeight.w500,
                  color: context.bull.error,
                  textAlign: TextAlign.center,
                  maxLines: 5,
                ),
                const Gap(BullSpacing.sm),
                BullButton.big(
                  label: l10n.refresh,
                  onPressed: widget.cubit.load,
                  bgColor: context.bull.surface,
                  textColor: context.bull.text,
                  outlined: true,
                ),
              ],
              if (state case ArkClaimRecoveryFinished(:final operation)) ...[
                BullText(
                  switch (operation.status) {
                    ArkOperationStatus.succeeded => l10n.claimConfirmed,
                    ArkOperationStatus.conflicted => l10n.claimConflict,
                    ArkOperationStatus.pending => l10n.pendingOperation,
                    ArkOperationStatus.failed => l10n.unavailable,
                    ArkOperationStatus.prepared ||
                    ArkOperationStatus.admitted ||
                    ArkOperationStatus.outcomeUnknown => l10n.uncertain,
                  },
                  role: BullTextRole.body,
                  textAlign: TextAlign.center,
                  maxLines: 5,
                ),
                const Gap(BullSpacing.sm),
                BullButton.big(
                  label: l10n.refresh,
                  onPressed: widget.cubit.load,
                  bgColor: context.bull.surface,
                  textColor: context.bull.text,
                  outlined: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
