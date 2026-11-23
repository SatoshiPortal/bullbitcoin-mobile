# Exchange

`Exchange.open` exposes a strict pending-order inventory and owns the scan's short-lived BBX client. It only returns false after a complete scan with a stable environment, credential and session epoch. The ordinary library publishes owned account and order values, including recurring purchases and KYC rules, without exposing BBX codecs.

Account reads, preferences, announcements, order statistics and KYC uploads use the same environment-bound capability and return typed failures. The account read distinguishes a server rejection from absent or unreadable credentials; the historical summary read preserves its missing-account semantics. File selection and validation stay with Exchange Settings.

Every exchange call runs on one client with the 30 s connect, send and receive timeouts, checked against the session before each request and disposed when the operation ends. Uploads (KYC documents, support messages with attachments) have no send timeout and report progress; their connect and receive timeouts still apply.

`Exchange.notifications` publishes decoded notification events and typed recoverable socket failures for the active environment. Failures do not close the stream or include raw frames. Session management owns when to connect and disconnect. `Exchange.close()` releases the socket and its subscriptions; obsolete connect and reconnect attempts do not reopen it.

`Exchange.limitOrders` owns order-trigger operations and rates. It maps the transport's rejection codes to typed limit-order problems.

`Exchange.funding` owns institutions, payment instructions and consent. It returns a typed refusal for incomplete instructions instead of returning unusable bank details.

`Exchange.virtualIbans` finds or provisions the virtual IBAN for an explicit exchange environment. A successful lookup with no IBAN returns `Ok(null)`; missing credentials and unavailable credentials remain distinct failures.

`Exchange.orders(environment)` reads history, matches on-chain and Payjoin transaction IDs, and places, confirms or refreshes orders in the matching authenticated session. Missing credentials make history empty but do not make the pending inventory authoritative. A failed credential read or a rejected session stays a failure. Default payout destinations are read and written through `Exchange`, and neither order nor payout writes are replayed when the session changes.

`package:exchange/setup.dart` gives the app's existing access coordinator the legacy credential lifecycle. The package owns the serialized record and validation; `secrets` owns the OS keychain. This does not move stored data or change sign-out policy.

`package:exchange/migration.dart` supplies the Exchange participant for the storage coordinator. It opens the owner database through `Secrets.databaseOpener` and the shared native-close admission, projects both fixed keychain records and all historical Basic Auth rows, and verifies the destination and its import or fresh receipt. The participant is not mounted until coordinator preflight and legacy writer admission are wired. It never deletes or updates either legacy source.

## Dependencies

- `bbx_api` supplies the authenticated transport for account, KYC, statistics, chat, notifications, funding, virtual IBANs, orders and default payouts.
- `legacy_storage` supplies the encrypted credential import contract; `secrets` supplies the scoped database key and legacy credential lifecycle.
- `preferences` supplies environment selection for legacy consumers.
