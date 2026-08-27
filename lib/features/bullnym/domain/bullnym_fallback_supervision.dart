final class BullnymFallbackInvoiceContext {
  final String status;
  final int amountSat;
  final int? fiatAmountMinor;
  final String? fiatCurrency;
  final String? publicDescription;
  final String? invoiceNumber;
  final int createdAtUnix;

  const BullnymFallbackInvoiceContext({
    required this.status,
    required this.amountSat,
    this.fiatAmountMinor,
    this.fiatCurrency,
    this.publicDescription,
    this.invoiceNumber,
    required this.createdAtUnix,
  });
}

final class BullnymFallbackSupervisionItem {
  final String invoiceId;
  final String nym;
  final String recoveryStatus;
  final int userLockAmountSat;
  final int serverLockAmountSat;
  final String lockupAddress;
  final String? refundAddress;
  final String? refundTxid;
  final int swapCreatedAtUnix;
  final int swapUpdatedAtUnix;
  final BullnymFallbackInvoiceContext invoice;

  const BullnymFallbackSupervisionItem({
    required this.invoiceId,
    required this.nym,
    required this.recoveryStatus,
    required this.userLockAmountSat,
    required this.serverLockAmountSat,
    required this.lockupAddress,
    this.refundAddress,
    this.refundTxid,
    required this.swapCreatedAtUnix,
    required this.swapUpdatedAtUnix,
    required this.invoice,
  });
}

final class BullnymFallbackSupervisionResponse {
  final List<BullnymFallbackSupervisionItem> items;
  final int count;
  final bool hasMore;

  const BullnymFallbackSupervisionResponse({
    required this.items,
    required this.count,
    required this.hasMore,
  });
}
