import 'package:meta/meta.dart';

/// Ark balance in sats, split by state.
@immutable
final class ArkBalance {
  final int spendableSats;

  /// Spendable, but close to expiry: refresh before it lapses.
  final int needsRefreshSats;
  final int pendingBoardSats;
  final int pendingInRoundSats;
  final int pendingExitSats;
  final int pendingSendSats;
  final int claimableLightningReceiveSats;

  const ArkBalance({
    required this.spendableSats,
    required this.needsRefreshSats,
    required this.pendingBoardSats,
    required this.pendingInRoundSats,
    required this.pendingExitSats,
    required this.pendingSendSats,
    required this.claimableLightningReceiveSats,
  });

  @override
  bool operator ==(Object other) =>
      other is ArkBalance &&
      other.spendableSats == spendableSats &&
      other.needsRefreshSats == needsRefreshSats &&
      other.pendingBoardSats == pendingBoardSats &&
      other.pendingInRoundSats == pendingInRoundSats &&
      other.pendingExitSats == pendingExitSats &&
      other.pendingSendSats == pendingSendSats &&
      other.claimableLightningReceiveSats == claimableLightningReceiveSats;

  @override
  int get hashCode => Object.hash(
    spendableSats,
    needsRefreshSats,
    pendingBoardSats,
    pendingInRoundSats,
    pendingExitSats,
    pendingSendSats,
    claimableLightningReceiveSats,
  );
}
