class PreparedLightningAddressWallet {
  final String walletId;
  final String ctDescriptor;
  final bool created;

  const PreparedLightningAddressWallet({
    required this.walletId,
    required this.ctDescriptor,
    required this.created,
  });
}
