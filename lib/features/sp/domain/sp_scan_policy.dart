import 'package:bb_mobile/features/sp/domain/sp_config.dart';

/// Blocks the wallet may lag the tip before a resume scan needs the user's
/// go-ahead. Roughly a month at mainnet pace.
const int spAutoScanMaxBlocksBehind = 30 * SpConfig.blocksPerDay;

/// What a sync tick may do with the SP scan cursor.
enum SpScanTrigger { manualOnly, automatic, needsConfirmation, upToDate }

/// Where the scan cursor sits against the chain tip, and what the app may do
/// about it.
///
/// A null [lastScannedHeight] means setup has not seeded a cursor yet, and a
/// null [chainTip] means the header store has not reported one. Neither is a
/// licence to guess.
class SpScanPolicy {
  final int? lastScannedHeight;
  final int? chainTip;
  final bool isAutoScanEnabled;

  SpScanPolicy({
    required this.lastScannedHeight,
    required this.chainTip,
    this.isAutoScanEnabled = true,
  }) {
    if (lastScannedHeight != null && lastScannedHeight! < 0) {
      throw ArgumentError.value(
        lastScannedHeight,
        'lastScannedHeight',
        'Block height cannot be negative',
      );
    }
    if (chainTip != null && chainTip! < 0) {
      throw ArgumentError.value(
        chainTip,
        'chainTip',
        'Chain tip cannot be negative',
      );
    }
  }

  /// Whether a sync tick may resume the scan on its own.
  ///
  /// An unknown cursor or tip stays [SpScanTrigger.manualOnly], as does auto
  /// scanning being switched off: the user asked to drive it, so they are never
  /// nudged either. A cursor at or past the tip is [SpScanTrigger.upToDate].
  SpScanTrigger get trigger {
    final last = lastScannedHeight;
    final tip = chainTip;
    if (!isAutoScanEnabled) return SpScanTrigger.manualOnly;
    if (last == null || tip == null) return SpScanTrigger.manualOnly;
    // The cursor follows the blindbit tip and [chainTip] follows the header
    // store, so the cursor sits ahead while headers catch up. Without this a
    // negative gap reads as automatic and every tip change rescans.
    if (last >= tip) return SpScanTrigger.upToDate;
    if (tip - last > spAutoScanMaxBlocksBehind) {
      return SpScanTrigger.needsConfirmation;
    }
    return SpScanTrigger.automatic;
  }

  /// True when the wallet is behind and nothing will bring it up to date on its
  /// own, so the UI should ask the user to scan.
  ///
  /// That is either because they turned automatic scanning off, or because the
  /// wallet drifted past [spAutoScanMaxBlocksBehind]. A wallet that is already
  /// synced needs nothing, and one with no cursor or no known tip cannot be
  /// judged, so neither is nudged.
  bool get needsUser {
    final last = lastScannedHeight;
    final tip = chainTip;
    if (last == null || tip == null) return false;
    if (last >= tip) return false;
    return trigger != SpScanTrigger.automatic;
  }

  /// Rough time the scanned tip was reached, from how far it sits below the
  /// chain tip. No per-block timestamp is stored, so this is an estimate at
  /// mainnet pace, only indicative on networks that mine on demand.
  ///
  /// Null when there is no cursor or no known tip to measure the gap against.
  DateTime? lastScannedEstimate({DateTime? now}) {
    final last = lastScannedHeight;
    final tip = chainTip;
    if (last == null || tip == null) return null;
    final behind = tip - last;
    final blocksBehind = behind > 0 ? behind : 0;
    return (now ?? DateTime.now()).subtract(
      Duration(minutes: blocksBehind * SpConfig.minutesPerBlock),
    );
  }
}
