# Exchange

`Exchange.open` exposes a strict pending-order inventory and owns the scan's short-lived BBX client. It only returns false after a complete scan with a stable environment, credential and session epoch. The ordinary library publishes owned account and order values, including recurring purchases and KYC rules, without exposing BBX codecs. The application still owns the session and its credential persistence during this slice; no legacy data is moved.

`package:exchange/migration.dart` supplies the Exchange participant for the storage coordinator. It opens the owner database through `Secrets.databaseKeys`, projects both fixed keychain records and all historical Basic Auth rows, and verifies the destination and its import or fresh receipt. The participant is not mounted until coordinator preflight and legacy writer admission are wired. It never deletes or updates either legacy source.
