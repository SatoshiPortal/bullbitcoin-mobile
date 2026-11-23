# Payjoin

Production and regtest use independent admitted, encrypted database families under the application's support `databases` directory. Standalone legacy files are opened read-only and projected from their historical schemas. Current sessions, policy flags, prior migration evidence and input reservation information are preserved.

The earlier root-import marker is not enough to certify all historical rows: it was computed after filtering. The encrypted cutover verifies its coverage and current identities before activation and does not quarantine or recreate unreadable files. No source files are retired by this owner.
