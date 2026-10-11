final class WalletInventoryRecovery {
  final Map<String, String> walletReferences;
  final List<String> failedReferences;

  WalletInventoryRecovery({
    required Map<String, String> walletReferences,
    required List<String> failedReferences,
  }) : walletReferences = Map.unmodifiable(walletReferences),
       failedReferences = List.unmodifiable(failedReferences) {
    if (walletReferences.values.toSet().length != walletReferences.length ||
        failedReferences.any(walletReferences.containsKey)) {
      throw const FormatException('Ambiguous recovered wallet references');
    }
  }

  bool get complete => failedReferences.isEmpty;
}
