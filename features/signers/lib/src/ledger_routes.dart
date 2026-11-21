enum LedgerRoute {
  importLedger('/ledger-import'),
  ledgerSignTransaction('/ledger-sign-transaction'),
  ledgerVerifyAddress('/ledger-verify-address');

  final String path;

  const LedgerRoute(this.path);
}
