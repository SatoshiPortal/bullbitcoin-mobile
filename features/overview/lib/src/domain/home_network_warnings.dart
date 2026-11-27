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
  }) async {
    if (_closed) return null;
    final version = ++_version;
    if (isLiquid) {
      _liquidDown = !success;
    } else {
      _bitcoinDown = !success;
    }
    final reason = switch ((_bitcoinDown, _liquidDown)) {
      (true, true) => ElectrumServerDown.both,
      (true, false) => ElectrumServerDown.bitcoin,
      (false, true) => ElectrumServerDown.liquid,
      (false, false) => null,
    };
    if (reason == null) return const [];
    final proxyNeedsAttention = _bitcoinDown && await _proxyNeedsAttention();
    if (_closed || version != _version) return null;
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

  void close() => _closed = true;
}
