import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:intl/intl.dart';
import 'package:primitives/primitives.dart';

import '../presentation/ark_l10n.dart';
import '../presentation/ark_movement_l10n.dart';
import 'ark_amount.dart';
import 'ark_short_id.dart';

/// One observed Ark movement, laid out like the app's transaction details:
/// direction badge, what happened, the amount, then the details table.
class ArkMovementDetailsScreen extends StatelessWidget {
  final ArkMovement movement;

  /// Leaves straight for the app's home, as after a finished flow; without
  /// it, closing returns to the previous page.
  final VoidCallback? onClose;

  const ArkMovementDetailsScreen({
    super.key,
    required this.movement,
    this.onClose,
  });

  /// Boards and Lightning receipts add to Ark, exits leave it; a payment can
  /// be either, and a renewal moves funds within Ark.
  bool? get _incoming => switch (movement.kind) {
    ArkMovementKind.board || ArkMovementKind.lightningReceive => true,
    ArkMovementKind.exit => false,
    ArkMovementKind.payment ||
    ArkMovementKind.renewal ||
    ArkMovementKind.unknown => null,
  };

  BullDetailsTableItem _copyable(
    BuildContext context,
    String label,
    String value,
  ) => BullDetailsTableItem(
    label: label,
    displayValue: value,
    copyValue: value,
    copiedMessage: context.loc.copied,
    displayWidget: BullText(
      arkShortId(value),
      role: BullTextRole.body,
      fontWeight: FontWeight.w500,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.loc;
    final incoming = _incoming;
    final txid = movement.transactionId;
    final fee = movement.fee;
    final amount = movement.amount;
    // Where the funds arrived for money coming in, where they went otherwise.
    final address = switch (incoming) {
      true => movement.receivedOn.firstOrNull,
      _ => movement.sentTo.firstOrNull,
    };
    // Coming in, the amount is what arrived. Within Ark (a renewal) or out
    // while pending, what arrives is the amount less its fee.
    final received = switch ((incoming, amount, fee)) {
      (true, _, _) => amount,
      (false, _, _) when movement.status != ArkMovementStatus.pending => null,
      (_, final amount?, final fee?) when fee.value <= amount.value => Sats(
        amount.value - fee.value,
      ),
      _ => null,
    };
    final confirmed = movement.status == ArkMovementStatus.successful
        ? movement.completedAt
        : null;
    final locale = Localizations.localeOf(context).toString();
    final close = onClose;
    return PopScope<Object?>(
      // Opened from a finished flow: back goes home directly, never through
      // the flow's own screen.
      canPop: close == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close?.call();
      },
      child: BullScaffold(
        backgroundColor: context.bull.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BullTopBar(
                title: l10n.movementDetailsTitle,
                onAction: close ?? () => Navigator.pop(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(BullSpacing.md),
                  child: Column(
                    children: [
                      BullTransactionDirectionBadge(
                        isIncoming: incoming ?? false,
                        isSwap: incoming == null,
                      ),
                      const Gap(BullSpacing.lg),
                      Semantics(
                        header: true,
                        child: BullText(
                          movement.kind.toTranslated(context),
                          role: BullTextRole.subtitle,
                          fontWeight: FontWeight.w700,
                          color: movement.status == ArkMovementStatus.failed
                              ? context.bull.error
                              : null,
                        ),
                      ),
                      BullText(
                        formatArkObservedSats(context, movement.amount),
                        role: BullTextRole.headline,
                        fontWeight: FontWeight.w500,
                        color: context.bull.secondary,
                      ),
                      const Gap(BullSpacing.md),
                      BullDetailsTable(
                        items: [
                          if (txid != null && txid.trim().isNotEmpty)
                            _copyable(context, l10n.transactionId, txid),
                          // As the app's transaction details: money coming in
                          // names the wallet it reached, anything else the
                          // wallet it left.
                          BullDetailsTableItem(
                            label: incoming == true
                                ? l10n.movementToWallet
                                : l10n.movementFromWallet,
                            displayValue: l10n.title,
                          ),
                          if (address != null)
                            _copyable(context, l10n.movementAddress, address),
                          if (incoming != true)
                            BullDetailsTableItem(
                              label: l10n.movementAmountSent,
                              displayValue: formatArkObservedSats(
                                context,
                                movement.amount,
                              ),
                            ),
                          if (received != null)
                            BullDetailsTableItem(
                              label: l10n.movementAmountReceived,
                              displayValue: formatArkSats(context, received),
                            ),
                          // Bark records only off-chain fees on a movement. An
                          // exit pays on-chain, so its 0 would be misleading.
                          if (incoming != true &&
                              fee != null &&
                              movement.kind != ArkMovementKind.exit)
                            BullDetailsTableItem(
                              label: l10n.movementFee,
                              displayValue: formatArkSats(context, fee),
                            ),
                          BullDetailsTableItem(
                            label: l10n.movementStatus,
                            displayValue: movement.status.toTranslated(context),
                          ),
                          if (confirmed != null)
                            BullDetailsTableItem(
                              label: l10n.movementConfirmationTime,
                              displayValue: DateFormat.yMMMMd(locale)
                                  .add_jm()
                                  .format(confirmed.toLocal()),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
