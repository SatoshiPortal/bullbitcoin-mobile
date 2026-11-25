/// An account group that lets the user trade in some markets. The names are
/// the server's (`API-Common/.../users/types/UserGroups.ts`).
enum KycGroup {
  identityVerified('KYC_IDENTITY_VERIFIED'),
  canadaLight('KYC_CANADA_LIGHT_VERIFICATION'),
  limited('KYC_LIMITED_VERIFICATION'),
  sinpeVerified('KYC_SINPE_VERIFIED'),
  missionary('MISSIONARY');

  const KycGroup(this.serverName);

  final String serverName;

  /// The KYC groups among the account's [groups]; other groups are ignored.
  static Set<KycGroup> fromServerGroups(Iterable<String> groups) => {
    for (final group in KycGroup.values)
      if (groups.contains(group.serverName)) group,
  };
}

/// Which KYC groups may trade in a market, and up to what amount per
/// transaction, following the server's published limits table
/// (`getTradingLimitAndVerificationsPerCountry` in API-Orders).
///
/// Daily caps are not modelled: the app has no daily volume, so the server
/// enforces them.
final class KycPolicy {
  /// The groups allowed to trade, with their per-transaction cap in the
  /// market's currency; null means no cap.
  final Map<KycGroup, double?> perTransactionCaps;

  const KycPolicy(this.perTransactionCaps);

  /// Whether any of [groups] may trade in this market at all.
  bool allowsTrading(Set<KycGroup> groups) =>
      groups.any(perTransactionCaps.containsKey);

  /// Whether one of [groups] may trade [amount] in one transaction.
  bool allowsAmount(Set<KycGroup> groups, double amount) => groups.any((group) {
    if (!perTransactionCaps.containsKey(group)) return false;
    final cap = perTransactionCaps[group];
    return cap == null || amount <= cap;
  });

  /// Whether the user must upgrade their KYC to trade [amount] here.
  bool needsUpgrade(Set<KycGroup> groups, double amount) =>
      !allowsAmount(groups, amount);
}
