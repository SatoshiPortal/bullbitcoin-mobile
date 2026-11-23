# Exchange

`Exchange.open` exposes a strict pending-order inventory and owns the scan's short-lived BBX client. It only returns false after a complete scan with a stable environment, credential and session epoch. The ordinary library publishes owned account and order values, including recurring purchases and KYC rules, without exposing BBX codecs. The application still owns the session and its credential persistence during this slice; no legacy data is moved.
