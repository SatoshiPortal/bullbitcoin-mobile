import 'package:flutter/material.dart';

/// The curated icon set `bull_ui` exposes. Feature code references these
/// instead of Material `Icons` directly, e.g. `BullIcon(BullIcons.acUnit)`.
///
/// Mirrors the Material icon names used in the design (§5.2). `call_merge`
/// (sweep-only) is deliberately omitted — there is no Sweep in scope.
abstract final class BullIcons {
  static const IconData tune = Icons.tune;
  static const IconData acUnit = Icons.ac_unit;
  static const IconData lockOpen = Icons.lock_open;
  static const IconData sync = Icons.sync;
  static const IconData checkCircle = Icons.check_circle;
  static const IconData schedule = Icons.schedule;
  static const IconData contentCopy = Icons.content_copy;
  static const IconData sell = Icons.sell;
  static const IconData close = Icons.close;
  static const IconData check = Icons.check;
  static const IconData swipe = Icons.swipe;
  static const IconData filterAltOff = Icons.filter_alt_off;
  static const IconData accountBalanceWallet = Icons.account_balance_wallet;
  static const IconData arrowBack = Icons.arrow_back;
  static const IconData chevronRight = Icons.chevron_right;
  static const IconData accountTree = Icons.account_tree;
  static const IconData deleteOutline = Icons.delete_outline;
  static const IconData errorOutline = Icons.error_outline;
}

/// A thin wrapper over the Flutter [Icon] so feature code never touches
/// Material's `Icon`/`Icons` directly. Pair with [BullIcons].
class BullIcon extends StatelessWidget {
  const BullIcon(this.icon, {super.key, this.size, this.color});

  /// The icon glyph — use a [BullIcons] constant.
  final IconData icon;

  /// Optional explicit size.
  final double? size;

  /// Optional explicit colour. Defaults to the ambient [IconTheme].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: size, color: color);
  }
}
