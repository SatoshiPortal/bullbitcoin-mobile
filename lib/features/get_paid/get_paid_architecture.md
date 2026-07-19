# Get Paid

Get Paid owns the wallet's receiving-product hub and its authenticated history
of payments received through Bullnym-backed Get Paid products.

## Scope

This feature owns:

- the dashboard that links to Lightning Address, Donation Page, Point of Sale,
  one-time invoice creation, BTCPay, and received Get Paid transactions;
- independent dashboard-card loading so a slow remote lookup does not hide the
  rest of the product surface;
- the Get Paid transaction entity, typed failure mapping, pagination state,
  and list/detail presentation;
- derivation of an ephemeral Bullnym server-auth signer at the point of the
  private history request.

It does not own Bullnym HTTP/signing rules, invoice settlement logic, payment
page or POS configuration, Lightning Address registration, wallet transaction
history, or wallet key storage. Those remain behind their owning feature/core
boundaries.

## Transaction History

`Transactions` is a private, identity-wide payment-evidence projection from
Bullnym. It contains evidenced Get Paid receipts from Lightning Address,
one-time invoices, Donation Pages, and Point of Sale. It is not an invoice list
and excludes unpaid or abandoned payment artifacts by server contract.

The client treats the server cursor as opaque. First load, pull-to-refresh, and
explicit load-more calls use the signed `get-paid-transaction-list` action.
Pages are deduplicated by `(source, transaction_id)`; neither identifier is
shown as user copy. Unknown source, rail, settlement state, malformed identity,
invalid source/invoice relationships, duplicate rows, or invalid cursor
progression fail closed at the Bullnym data boundary.

Rows show amount, source, receipt time, rail, and settlement state. Optional
payer comments appear only on the transaction detail screen. Invoice-backed
details may navigate to the existing invoice detail using the server-provided
invoice id; Lightning Address receipts never carry an invoice id.

## Privacy And Identity

The history endpoint is authenticated with the existing Bullnym server-auth
Nostr role derived from the current default Bitcoin wallet xprv. The xprv and
signer are created only for the request and are not stored in Get Paid state.
Bullnym receives the derived public key, signed cursor/limit request, and
response metadata; it does not receive the wallet seed or xprv.

Comments and internal identifiers are not logged, shared, or rendered in list
rows. The response is handled as private no-store data and is kept only in
memory by the history cubit.

## Dependencies

The presentation flow is:

`UI -> GetPaidTransactionHistoryCubit -> ListGetPaidTransactionsUsecase -> BullnymFacade`

The use case also consumes `NostrIdentityFacade` and a Get Paid-owned default
wallet xprv capability implemented against core wallet/seed infrastructure.
Cross-feature calls use public facades, and `FEATURES.md` records those edges.
