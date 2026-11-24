import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:intl/intl.dart';

import '../presentation/ark_l10n.dart';
import '../presentation/ark_movement_l10n.dart';
import 'ark_amount.dart';
import 'ark_movement_details_screen.dart';

/// Observed Ark movements, laid out like the app's wallet transactions and
/// grouped by day: Today, Yesterday, then dates. An unsettled movement stays
/// on its day and says "Pending" on its row.
///
/// Observations carry no history-completeness evidence: an empty list renders
/// "nothing observed yet", never a claim that the account has no history.
class ArkActivityList extends StatelessWidget {
  final List<ArkMovement> movements;

  ArkActivityList({super.key, required List<ArkMovement> movements})
    // A Board left before funding moved nothing, so it is not activity.
    : movements = movements.where((m) => !m.isUnfundedBoard).toList();

  static String _day(BuildContext context, DateTime? time) {
    final l10n = context.loc;
    if (time == null) return l10n.walletActivityDateUnknown;
    final local = time.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return l10n.activityToday;
    if (day == today.subtract(const Duration(days: 1))) {
      return l10n.activityYesterday;
    }
    final locale = Localizations.localeOf(context).toString();
    return day.year == now.year
        ? DateFormat.MMMMd(locale).format(day)
        : DateFormat.yMMMMd(locale).format(day);
  }

  @override
  Widget build(BuildContext context) {
    if (movements.isEmpty) return const _ArkActivityEmpty();
    final groups = <String, List<ArkMovement>>{};
    for (final movement in movements) {
      groups
          .putIfAbsent(_day(context, movement.createdAt), () => [])
          .add(movement);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups.entries) ...[
          Semantics(
            header: true,
            child: BullText(
              group.key,
              role: BullTextRole.label,
              color: context.bull.onSurface,
            ),
          ),
          const Gap(BullSpacing.md),
          for (final movement in group.value)
            ArkActivityTile(movement: movement),
          const Gap(BullSpacing.md),
        ],
      ],
    );
  }
}

/// Matches the app's Bitcoin and Liquid wallets: one centred line.
class _ArkActivityEmpty extends StatelessWidget {
  const _ArkActivityEmpty();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: BullSpacing.md),
    child: BullText(
      context.loc.walletActivityEmptyTitle,
      role: BullTextRole.body,
      maxLines: 2,
      textAlign: TextAlign.center,
    ),
  );
}

/// One observed movement, styled like the app's transaction row. Tapping
/// opens its details, styled like the app's transaction details.
class ArkActivityTile extends StatelessWidget {
  final ArkMovement movement;

  const ArkActivityTile({super.key, required this.movement});

  @override
  Widget build(BuildContext context) {
    final l10n = context.loc;
    final amount = formatArkObservedSats(context, movement.amount);
    final status = movement.status.toTranslated(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: BullSpacing.xs),
      child: Semantics(
        button: true,
        label: '$amount, ${movement.kind.toTranslated(context)}, $status',
        hint: l10n.walletActivityShowDetails,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ArkMovementDetailsScreen(movement: movement),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(BullSpacing.md),
            decoration: BoxDecoration(
              color: context.bull.surface,
              borderRadius: BorderRadius.circular(context.bullShapes.card),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(BullSpacing.xs),
                  decoration: BoxDecoration(
                    color: context.bull.surface,
                    border: Border.all(color: context.bull.border),
                    borderRadius: BorderRadius.circular(
                      context.bullShapes.card,
                    ),
                  ),
                  child: BullIcon(
                    arkMovementIcon(movement.kind),
                    color: context.bull.onSurface,
                  ),
                ),
                const Gap(BullSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BullText(
                        amount,
                        role: BullTextRole.body,
                        fontWeight: FontWeight.w500,
                      ),
                      // A plain payment needs no label: its direction shows.
                      if (movement.kind != ArkMovementKind.payment) ...[
                        const Gap(BullSpacing.xxs),
                        _KindChip(movement.kind.toTranslated(context)),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    BullBadge(
                      label: l10n.title,
                      background: context.bull.bitcoinOrange,
                      foreground: context.bull.onSurface,
                      radius: context.bullShapes.badge,
                      textStyle: context.bullType.caption,
                      padding: const EdgeInsets.symmetric(
                        horizontal: BullSpacing.xxs,
                        vertical: 2,
                      ),
                    ),
                    const Gap(BullSpacing.xxs),
                    _status(context),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // As the app's rows: settled shows when with a check, pending says so.
  Widget _status(BuildContext context) {
    final time = movement.createdAt;
    return switch (movement.status) {
      ArkMovementStatus.successful when time != null => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BullText(
            bullTimeAgo(context, time),
            role: BullTextRole.caption,
            color: context.bull.textMuted,
          ),
          const Gap(BullSpacing.xxs),
          BullIcon(
            BullIcons.checkCircle,
            size: 12,
            color: context.bull.success,
          ),
        ],
      ),
      ArkMovementStatus.failed => BullText(
        movement.status.toTranslated(context),
        role: BullTextRole.caption,
        color: context.bull.error,
      ),
      _ => BullText(
        movement.status == ArkMovementStatus.pending
            ? movement.status.toTranslated(context)
            : time == null
            ? movement.status.toTranslated(context)
            : bullTimeAgo(context, time),
        role: BullTextRole.caption,
        color: context.bull.textMuted,
      ),
    };
  }
}

/// The kind of movement, in the chip style the app uses for notes.
class _KindChip extends StatelessWidget {
  final String label;

  const _KindChip(this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: BullSpacing.xs,
      vertical: BullSpacing.xxs,
    ),
    decoration: BoxDecoration(
      color: context.bull.onSecondary,
      borderRadius: BorderRadius.circular(context.bullShapes.chip),
      border: Border.all(color: context.bull.secondaryFixedDim),
    ),
    child: BullText(
      label,
      role: BullTextRole.caption,
      fontWeight: FontWeight.w500,
      color: context.bull.secondary,
    ),
  );
}

/// Payments merge sends and received Ark payments: their direction is unknown.
IconData arkMovementIcon(ArkMovementKind kind) => switch (kind) {
  ArkMovementKind.board ||
  ArkMovementKind.lightningReceive => BullIcons.arrowDownward,
  ArkMovementKind.exit => BullIcons.arrowUpward,
  ArkMovementKind.payment => BullIcons.swapHoriz,
  ArkMovementKind.renewal => BullIcons.sync,
  ArkMovementKind.unknown => BullIcons.history,
};
