class WalletWarning {
  final String title;
  final String description;
  final String actionRoute;
  final WarningType type;
  WalletWarning({
    required this.title,
    required this.description,
    required this.actionRoute,
    required this.type,
  });
}

enum WarningType { info, error }
