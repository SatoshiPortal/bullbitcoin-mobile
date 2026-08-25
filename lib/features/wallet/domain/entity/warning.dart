class WalletWarning {
  final String title;
  final String description;
  final WalletWarningAction action;
  final WarningType type;
  WalletWarning({
    required this.title,
    required this.description,
    required this.action,
    required this.type,
  });
}

enum WarningType { info, error }

enum WalletWarningAction { electrumSettings, torSettings }
