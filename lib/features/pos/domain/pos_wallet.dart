class PreparedPosWallet {
  final String walletId;
  final String ctDescriptor;
  final bool created;

  const PreparedPosWallet({
    required this.walletId,
    required this.ctDescriptor,
    required this.created,
  });
}
