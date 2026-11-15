enum ScanAction {
  send,
  exploreAddress,
  buyToAddress,
  importWatchOnly,
  importRemoteSigner,
  reviewAndBroadcast,
  exploreTransaction,
  importRecoveryPhrase,
  addElectrumServer,
  importLabels,
  swapToAddress,
  openWallet,
  copy;

  bool get requiresExchangeSession => this == ScanAction.buyToAddress;
}
