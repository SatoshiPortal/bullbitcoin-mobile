final class DefaultWalletsViewData {
  final String bitcoinAddress;
  final String lightningAddress;
  final String liquidAddress;
  final bool isLoading;
  final bool isSaving;
  final bool isEditing;

  const DefaultWalletsViewData({
    required this.bitcoinAddress,
    required this.lightningAddress,
    required this.liquidAddress,
    required this.isLoading,
    required this.isSaving,
    required this.isEditing,
  });

  bool get hasAnyWallet =>
      bitcoinAddress.isNotEmpty ||
      lightningAddress.isNotEmpty ||
      liquidAddress.isNotEmpty;
}
