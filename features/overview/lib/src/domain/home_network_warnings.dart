/// Which electrum servers are failing to sync.
///
/// The bloc used to build an English sentence here ("Bitcoin & Liquid electrum
/// server failure") and the UI rendered it verbatim, so the warning was
/// untranslated in every locale. The reason is a type now; the wording belongs
/// to the presentation layer (#1895).
enum ElectrumServerDown { bitcoin, liquid, both }

class WalletWarning {
  final ElectrumServerDown reason;
  final WalletWarningAction action;
  final WarningType type;

  const WalletWarning({
    required this.reason,
    required this.action,
    required this.type,
  });
}

enum WarningType { info, error }

enum WalletWarningAction { electrumSettings, torSettings }

/// The Home decision uses the Network owner's proxy diagnostic. A Liquid
/// failure alone never needs a proxy check.
final class HomeNetworkWarnings {
  final Future<bool> Function() _proxyNeedsAttention;
  bool _bitcoinDown = false;
  bool _liquidDown = false;
  bool _closed = false;
  int _version = 0;

  HomeNetworkWarnings(this._proxyNeedsAttention);

  /// Null retires this decision without changing the current carousel.
  Future<List<WalletWarning>?> update({
    required bool isLiquid,
    required bool success,
    required bool Function() isCurrent,
  }) async {
    if (_closed) return null;
    final version = ++_version;
    final bitcoinDown = isLiquid ? _bitcoinDown : !success;
    final liquidDown = isLiquid ? !success : _liquidDown;
    final reason = switch ((bitcoinDown, liquidDown)) {
      (true, true) => ElectrumServerDown.both,
      (true, false) => ElectrumServerDown.bitcoin,
      (false, true) => ElectrumServerDown.liquid,
      (false, false) => null,
    };
    final proxyNeedsAttention =
        reason != null && bitcoinDown && await _proxyNeedsAttention();
    if (_closed || version != _version || !isCurrent()) return null;
    _bitcoinDown = bitcoinDown;
    _liquidDown = liquidDown;
    if (reason == null) return const [];
    return [
      WalletWarning(
        reason: reason,
        action: proxyNeedsAttention
            ? WalletWarningAction.torSettings
            : WalletWarningAction.electrumSettings,
        type: WarningType.error,
      ),
    ];
  }

  /// Starts a new catalogue epoch: both the published facts and any pending
  /// proxy diagnostic belong to the retired inventory.
  void reset() {
    _version++;
    _bitcoinDown = false;
    _liquidDown = false;
  }

  void close() => _closed = true;
}
