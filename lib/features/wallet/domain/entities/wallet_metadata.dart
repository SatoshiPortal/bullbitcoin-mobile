enum WalletType { bdk, lwk }

class WalletMetadata {
  final String id;
  final WalletType type;
  final String name;

  WalletMetadata({
    required this.id,
    required this.type,
    required this.name,
  });
}
