/// Blocks the Blindbit server may sit below the header tip before the user is
/// warned.
const int spBlindbitMaxBlocksBehind = 3;

/// The Blindbit tip a scan ran up to, against the header tip at that moment.
///
/// A scan stops at the Blindbit tip, so payments in the blocks above it are
/// missed until the server catches up. Both tips are taken when the scan
/// starts: comparing an old Blindbit tip with a header tip that kept moving
/// would warn every time blocks land between two scans.
class SpBlindbitLag {
  final int blindbitTip;
  final int chainTip;

  SpBlindbitLag({required this.blindbitTip, required this.chainTip}) {
    if (blindbitTip < 0) {
      throw ArgumentError.value(
        blindbitTip,
        'blindbitTip',
        'Block height cannot be negative',
      );
    }
    if (chainTip < 0) {
      throw ArgumentError.value(
        chainTip,
        'chainTip',
        'Chain tip cannot be negative',
      );
    }
  }

  int get blocksBehind => chainTip - blindbitTip;

  /// True when the server is more than [spBlindbitMaxBlocksBehind] blocks
  /// behind, so recent payments may be missing.
  bool get isBehind => blocksBehind > spBlindbitMaxBlocksBehind;
}
