const String bullpayActionGetPaidTransactionList = 'get-paid-transaction-list';

/// The identity-wide signed payload is `[cursor_or_empty, limit]`. The LA-v2
/// nym slot is always empty and the cursor is opaque to the client.
List<String> buildGetPaidTransactionListPayloadFields({
  required String cursor,
  required int limit,
}) {
  return [cursor, limit.toString()];
}
