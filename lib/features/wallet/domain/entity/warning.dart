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
