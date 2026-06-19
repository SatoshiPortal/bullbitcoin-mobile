import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';

/// A circular badge that indicates a transaction's direction — duplicated from
/// `core/widgets/badges/transaction_direction_badge.dart`.
///
/// Shows a swap glyph when [isSwap], otherwise an inbound/outbound arrow based
/// on [isIncoming].
class BullTransactionDirectionBadge extends StatelessWidget {
  const BullTransactionDirectionBadge({
    super.key,
    required this.isIncoming,
    this.isSwap = false,
  });

  /// Whether the transaction is incoming (vs outgoing).
  final bool isIncoming;

  /// Renders a swap glyph, overriding the directional arrow.
  final bool isSwap;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        border: Border.all(color: colors.surface),
        color: colors.onSecondary,
        borderRadius: BorderRadius.circular(60),
        boxShadow: [
          BoxShadow(
            color: colors.scrim,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        isSwap
            ? Icons.swap_vert
            : isIncoming
            ? Icons.south_east
            : Icons.north_east,
        color: colors.secondary,
      ),
    );
  }
}
