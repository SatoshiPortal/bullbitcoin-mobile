enum BitBoxRoute {
  importBitBox('/bitbox-import'),
  bitboxSignTransaction('/bitbox-sign-transaction'),
  bitboxVerifyAddress('/bitbox-verify-address');

  final String path;

  const BitBoxRoute(this.path);
}
