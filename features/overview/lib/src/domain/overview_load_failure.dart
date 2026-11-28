/// The user-facing meaning of a Home load or refresh failure.
///
/// Home decides the category; the presentation layer owns the wording, so the
/// same category can stay untranslated-free and still read correctly in every
/// locale (#1895).
enum OverviewLoadFailure {
  balancesMayBeStale,
  loadFailed,
  cannotDeleteDefaultWallet,
  cannotDeleteWithOngoingSwaps,
  walletNotFound,
  unexpected,
}
